defmodule ServidorCentral do
  @moduledoc """
  Servidor Central del sistema de lotería.
  Corre como GenServer registrado globalmente (:global) para que
  los nodos clientes (admin y jugador) puedan localizarlo por nombre
  sin conocer su PID exacto.
  """

  use GenServer

  @nombre_global :servidor_central
  @ruta "datos/sorteos.json"

  # ─────────────────────────────────────────────
  # API pública — llamada desde cualquier nodo
  # ─────────────────────────────────────────────

  def iniciar do
    GenServer.start_link(__MODULE__, %{}, name: {:global, @nombre_global})
  end

  def llamar_servidor(accion, args \\ []) do
    case :global.whereis_name(@nombre_global) do
      :undefined ->
        {:error, "Servidor central no disponible. ¿Está corriendo nodo_servidor.exs?"}
      pid ->
        GenServer.call(pid, {accion, args}, 10_000)
    end
  end

  # ─────────────────────────────────────────────
  # Callbacks GenServer
  # ─────────────────────────────────────────────

  @impl true
  def init(_) do
    IO.puts("[ServidorCentral] Iniciado en nodo: #{Node.self()}")
    reanudar_servidores_sorteo()
    {:ok, %{}}
  end

  # ── Crear sorteo ──────────────────────────────
  @impl true
  def handle_call({:crear_sorteo, [nombre, fecha, valor, fracciones, cantidad]}, _from, estado) do
    sorteo      = Sorteo.crear(nombre, fecha, valor, cantidad, fracciones)
    pid         = ServidorSorteo.iniciar(sorteo)
    nombre_atom = String.to_atom(nombre)

    unless Process.whereis(nombre_atom), do: Process.register(pid, nombre_atom)

    guardar_sorteo(%{data: sorteo})
    registrar_bitacora("crear_sorteo", nombre, :ok)

    {:reply, {:ok, "Sorteo '#{nombre}' creado correctamente"}, estado}
  end

  # ── Listar sorteos ordenados por fecha ────────
  @impl true
  def handle_call({:listar_sorteos, []}, _from, estado) do
    lista =
      leer_sorteos()
      |> Enum.sort_by(fn s -> s.data.fecha end)

    registrar_bitacora("listar_sorteos", "-", :ok)
    {:reply, {:ok, lista}, estado}
  end

  # ── Ver detalle ───────────────────────────────
  @impl true
  def handle_call({:ver_detalle_sorteo, [nombre]}, _from, estado) do
    lista = leer_sorteos()

    case Enum.find(lista, fn s -> s.data.nombre == nombre end) do
      nil ->
        registrar_bitacora("ver_detalle", nombre, :negado)
        {:reply, {:error, "Sorteo '#{nombre}' no encontrado"}, estado}

      entrada ->
        registrar_bitacora("ver_detalle", nombre, :ok)
        {:reply, {:ok, entrada.data}, estado}
    end
  end

  # ── Comprar billete completo ──────────────────
  @impl true
  def handle_call({:comprar_billete, [nombre_sorteo, cliente, numero]}, _from, estado) do
    case obtener_o_iniciar_servidor(nombre_sorteo) do
      nil ->
        registrar_bitacora("comprar_billete", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo '#{nombre_sorteo}' no existe"}, estado}

      pid ->
        send(pid, {:comprar, cliente, numero, self(), self()})
        resultado = esperar_respuesta_compra()

        registrar_bitacora(
          "comprar_billete",
          "#{nombre_sorteo} billete ##{numero}",
          if(match?({:ok, _}, resultado), do: :ok, else: :negado)
        )

        {:reply, resultado, estado}
    end
  end

  # ── Comprar fracción de billete ───────────────
  @impl true
  def handle_call({:comprar_fraccion, [nombre_sorteo, cliente, numero_billete, numero_fraccion]}, _from, estado) do
    case obtener_o_iniciar_servidor(nombre_sorteo) do
      nil ->
        registrar_bitacora("comprar_fraccion", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo '#{nombre_sorteo}' no existe"}, estado}

      pid ->
        send(pid, {:comprar_fraccion, cliente, numero_billete, numero_fraccion, self(), self()})
        resultado = esperar_respuesta_compra()

        registrar_bitacora(
          "comprar_fraccion",
          "#{nombre_sorteo} billete ##{numero_billete} fracción ##{numero_fraccion}",
          if(match?({:ok, _}, resultado), do: :ok, else: :negado)
        )

        {:reply, resultado, estado}
    end
  end

  # ── Ver apuestas ──────────────────────────────
  @impl true
  def handle_call({:ver_apuestas, [nombre_sorteo]}, _from, estado) do
    case obtener_o_iniciar_servidor(nombre_sorteo) do
      nil ->
        registrar_bitacora("ver_apuestas", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo no encontrado"}, estado}

      pid ->
        send(pid, {:obtener_apuestas, self()})

        resultado =
          receive do
            {:apuestas, apuestas} -> {:ok, apuestas}
          after 5_000 ->
            {:error, "Sin respuesta del servidor de sorteo"}
          end

        registrar_bitacora("ver_apuestas", nombre_sorteo, :ok)
        {:reply, resultado, estado}
    end
  end

  # ── Consultar clientes agrupados ──────────────
  @impl true
  def handle_call({:consultar_clientes, [nombre_sorteo]}, _from, estado) do
    lista = leer_sorteos()

    case Enum.find(lista, fn s -> s.data.nombre == nombre_sorteo end) do
      nil ->
        registrar_bitacora("consultar_clientes", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo '#{nombre_sorteo}' no encontrado"}, estado}

      entrada ->
        apuestas = entrada.data.apuestas

        completos =
          apuestas
          |> Enum.filter(fn a -> a.tipo == "completo" or a.tipo == :completo end)
          |> Enum.sort_by(fn a -> a.cliente.nombre end)

        fracciones =
          apuestas
          |> Enum.filter(fn a -> a.tipo == "fraccion" or a.tipo == :fraccion end)
          |> Enum.sort_by(fn a -> a.cliente.nombre end)

        registrar_bitacora("consultar_clientes", nombre_sorteo, :ok)
        {:reply, {:ok, %{completos: completos, fracciones: fracciones}}, estado}
    end
  end

  # ── Consultar ingresos por sorteo ─────────────
  @impl true
  def handle_call({:consultar_ingresos, [nombre_sorteo]}, _from, estado) do
    lista = leer_sorteos()

    case Enum.find(lista, fn s -> s.data.nombre == nombre_sorteo end) do
      nil ->
        registrar_bitacora("consultar_ingresos", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo '#{nombre_sorteo}' no encontrado"}, estado}

      entrada ->
        sorteo   = entrada.data
        ingresos = calcular_ingresos(sorteo)

        registrar_bitacora("consultar_ingresos", nombre_sorteo, :ok)
        {:reply, {:ok, ingresos}, estado}
    end
  end

  # ── Consultar premios entregados en sorteos pasados ──
  @impl true
  def handle_call({:consultar_premios_pasados, []}, _from, estado) do
    resultado =
      leer_sorteos()
      |> Enum.filter(fn s -> s.data.jugado end)
      |> Enum.map(fn entrada ->
        sorteo        = entrada.data
        ingresos      = calcular_ingresos(sorteo)
        total_premios = sorteo.premios |> Enum.map(fn p -> p.valor end) |> Enum.sum()

        ganadores =
          sorteo.apuestas
          |> Enum.filter(fn a -> a.numero == sorteo.ganador end)
          |> Enum.map(fn a -> a.cliente.nombre end)

        %{
          nombre:             sorteo.nombre,
          premios:            sorteo.premios,
          ganadores:          ganadores,
          dinero_recolectado: ingresos,
          total_premios:      total_premios,
          balance:            ingresos - total_premios
        }
      end)

    registrar_bitacora("consultar_premios_pasados", "-", :ok)
    {:reply, {:ok, resultado}, estado}
  end

  # ── Consultar balance de todos los sorteos pasados ──
  @impl true
  def handle_call({:consultar_balance, []}, _from, estado) do
    detalle =
      leer_sorteos()
      |> Enum.filter(fn s -> s.data.jugado end)
      |> Enum.map(fn entrada ->
        sorteo        = entrada.data
        ingresos      = calcular_ingresos(sorteo)
        total_premios = sorteo.premios |> Enum.map(fn p -> p.valor end) |> Enum.sum()

        %{
          nombre:   sorteo.nombre,
          fecha:    sorteo.fecha,
          ingresos: ingresos,
          premios:  total_premios,
          balance:  ingresos - total_premios
        }
      end)

    total_acumulado = detalle |> Enum.map(fn d -> d.balance end) |> Enum.sum()

    registrar_bitacora("consultar_balance", "-", :ok)
    {:reply, {:ok, %{detalle: detalle, total: total_acumulado}}, estado}
  end

  # ── Realizar sorteo ───────────────────────────
  @impl true
  def handle_call({:realizar_sorteo, [nombre_sorteo]}, _from, estado) do
    case obtener_o_iniciar_servidor(nombre_sorteo) do
      nil ->
        registrar_bitacora("realizar_sorteo", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo no encontrado"}, estado}

      pid ->
        send(pid, {:realizar_sorteo, self(), self()})

        resultado =
          receive do
            {:ok, msg} ->
              receive do
                {:actualizar_sorteo, nuevo_sorteo} -> actualizar_en_json(nuevo_sorteo)
              after 1_000 -> :ok
              end
              {:ok, msg}

            {:error, msg} -> {:error, msg}
          after 5_000 ->
            {:error, "Sin respuesta del servidor de sorteo"}
          end

        registrar_bitacora(
          "realizar_sorteo",
          nombre_sorteo,
          if(match?({:ok, _}, resultado), do: :ok, else: :negado)
        )

        {:reply, resultado, estado}
    end
  end

  # ── Eliminar sorteo (solo si no tiene premios) ──
  @impl true
  def handle_call({:eliminar_sorteo, [nombre_sorteo]}, _from, estado) do
    lista = leer_sorteos()

    case Enum.find(lista, fn s -> s.data.nombre == nombre_sorteo end) do
      nil ->
        registrar_bitacora("eliminar_sorteo", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo '#{nombre_sorteo}' no encontrado"}, estado}

      entrada ->
        sorteo        = entrada.data
        tiene_premios = sorteo.premios != [] and sorteo.premios != nil

        if tiene_premios do
          registrar_bitacora("eliminar_sorteo", nombre_sorteo, :negado)
          {:reply, {:error, "No se puede eliminar: el sorteo tiene premios asociados"}, estado}
        else
          nueva_lista = Enum.reject(lista, fn s -> s.data.nombre == nombre_sorteo end)
          File.write!(@ruta, Jason.encode!(nueva_lista, pretty: true))

          nombre_atom = String.to_atom(nombre_sorteo)
          if Process.whereis(nombre_atom), do: Process.unregister(nombre_atom)

          registrar_bitacora("eliminar_sorteo", nombre_sorteo, :ok)
          {:reply, {:ok, "Sorteo '#{nombre_sorteo}' eliminado"}, estado}
        end
    end
  end

  # ── Consultar disponibilidad de billetes y fracciones ─────────
  @impl true
  def handle_call({:consultar_disponibles, [nombre_sorteo]}, _from, estado) do
    lista = leer_sorteos()

    case Enum.find(lista, fn s -> s.data.nombre == nombre_sorteo end) do
      nil ->
        registrar_bitacora("consultar_disponibles", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo '#{nombre_sorteo}' no encontrado"}, estado}

      entrada ->
        sorteo = entrada.data

        completos_disp =
          sorteo.billetes
          |> Enum.reject(fn b -> b.vendido end)
          |> Enum.map(fn b -> b.numero end)

        fracciones_disp =
          sorteo.billetes
          |> Enum.flat_map(fn b ->
            unless b.vendido do
              b.fracciones
              |> Enum.reject(fn f -> f.vendida end)
              |> Enum.map(fn f -> %{billete: b.numero, fraccion: f.numero_fraccion} end)
            else
              []
            end
          end)

        registrar_bitacora("consultar_disponibles", nombre_sorteo, :ok)
        {:reply, {:ok, %{completos: completos_disp, fracciones: fracciones_disp}}, estado}
    end
  end

  # ── Devolver compra (billete completo o fracción) ─────────────
  @impl true
  def handle_call({:devolver_compra, [nombre_sorteo, nombre_cliente, numero_billete, tipo, numero_fraccion]}, _from, estado) do
    case obtener_o_iniciar_servidor(nombre_sorteo) do
      nil ->
        registrar_bitacora("devolver_compra", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo '#{nombre_sorteo}' no existe"}, estado}

      pid ->
        send(pid, {:devolver_compra, nombre_cliente, numero_billete, tipo, numero_fraccion, self()})

        resultado =
          receive do
            {:ok, msg} ->
              receive do
                {:actualizar_sorteo, nuevo_sorteo} -> actualizar_en_json(nuevo_sorteo)
              after 1_000 -> :ok
              end
              {:ok, msg}

            {:error, msg} -> {:error, msg}
          after 5_000 ->
            {:error, "Sin respuesta del servidor de sorteo"}
          end

        registrar_bitacora(
          "devolver_compra",
          "#{nombre_sorteo} billete ##{numero_billete}",
          if(match?({:ok, _}, resultado), do: :ok, else: :negado)
        )

        {:reply, resultado, estado}
    end
  end

  # ── Crear premio para un sorteo ───────────────
  @impl true
  def handle_call({:crear_premio, [nombre_sorteo, nombre_premio, valor_premio]}, _from, estado) do
    lista = leer_sorteos()

    case Enum.find(lista, fn s -> s.data.nombre == nombre_sorteo end) do
      nil ->
        registrar_bitacora("crear_premio", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo '#{nombre_sorteo}' no encontrado"}, estado}

      entrada ->
        sorteo = entrada.data

        if sorteo.jugado do
          registrar_bitacora("crear_premio", nombre_sorteo, :negado)
          {:reply, {:error, "No se puede agregar premios a un sorteo finalizado"}, estado}
        else
          nuevo_premio = %{nombre: nombre_premio, valor: valor_premio}
          premios_act  = Map.get(sorteo, :premios, []) ++ [nuevo_premio]
          sorteo_act   = %{sorteo | premios: premios_act}

          nueva_lista =
            Enum.map(lista, fn s ->
              if s.data.nombre == nombre_sorteo, do: %{s | data: sorteo_act}, else: s
            end)

          File.write!(@ruta, Jason.encode!(nueva_lista, pretty: true))

          registrar_bitacora("crear_premio", "#{nombre_sorteo} - #{nombre_premio}", :ok)
          {:reply, {:ok, "Premio '#{nombre_premio}' creado para el sorteo '#{nombre_sorteo}'"}, estado}
        end
    end
  end

  # ── Listar premios agrupados por sorteo, ordenados por fecha ──
  @impl true
  def handle_call({:listar_premios, []}, _from, estado) do
    resultado =
      leer_sorteos()
      |> Enum.sort_by(fn s -> s.data.fecha end)
      |> Enum.map(fn entrada ->
        sorteo  = entrada.data
        premios = Map.get(sorteo, :premios, [])
        %{sorteo: sorteo.nombre, fecha: sorteo.fecha, premios: premios}
      end)

    registrar_bitacora("listar_premios", "-", :ok)
    {:reply, {:ok, resultado}, estado}
  end

  # ── Eliminar premio (solo si el sorteo no tiene clientes) ──────
  @impl true
  def handle_call({:eliminar_premio, [nombre_sorteo, nombre_premio]}, _from, estado) do
    lista = leer_sorteos()

    case Enum.find(lista, fn s -> s.data.nombre == nombre_sorteo end) do
      nil ->
        registrar_bitacora("eliminar_premio", nombre_sorteo, :negado)
        {:reply, {:error, "Sorteo '#{nombre_sorteo}' no encontrado"}, estado}

      entrada ->
        sorteo         = entrada.data
        tiene_clientes = sorteo.apuestas != [] and sorteo.apuestas != nil

        if tiene_clientes do
          registrar_bitacora("eliminar_premio", nombre_sorteo, :negado)
          {:reply, {:error, "No se puede eliminar el premio: el sorteo ya tiene clientes asociados"}, estado}
        else
          premios_nuevos = Enum.reject(Map.get(sorteo, :premios, []), fn p -> p.nombre == nombre_premio end)
          sorteo_act     = %{sorteo | premios: premios_nuevos}

          nueva_lista =
            Enum.map(lista, fn s ->
              if s.data.nombre == nombre_sorteo, do: %{s | data: sorteo_act}, else: s
            end)

          File.write!(@ruta, Jason.encode!(nueva_lista, pretty: true))

          registrar_bitacora("eliminar_premio", "#{nombre_sorteo} - #{nombre_premio}", :ok)
          {:reply, {:ok, "Premio '#{nombre_premio}' eliminado del sorteo '#{nombre_sorteo}'"}, estado}
        end
    end
  end

  # ── Fallback ──────────────────────────────────
  @impl true
  def handle_call(msg, _from, estado) do
    IO.puts("[ServidorCentral] Mensaje desconocido: #{inspect(msg)}")
    {:reply, {:error, "Acción no reconocida"}, estado}
  end

  # ─────────────────────────────────────────────
  # Helpers privados
  # ─────────────────────────────────────────────

  defp leer_sorteos do
    case File.read(@ruta) do
      {:ok, contenido} -> Jason.decode!(contenido, keys: :atoms)
      _                -> []
    end
  end

  defp guardar_sorteo(sorteo) do
    lista       = leer_sorteos()
    nueva_lista = [sorteo | lista]
    File.write!(@ruta, Jason.encode!(nueva_lista, pretty: true))
  end

  defp actualizar_en_json(nuevo_sorteo) do
    lista = leer_sorteos()

    nueva_lista =
      Enum.map(lista, fn s ->
        if s.data.nombre == nuevo_sorteo.nombre,
          do:   %{s | data: nuevo_sorteo},
          else: s
      end)

    File.write!(@ruta, Jason.encode!(nueva_lista, pretty: true))
  end

  defp obtener_o_iniciar_servidor(nombre_sorteo) do
    nombre_atom = String.to_atom(nombre_sorteo)

    case Process.whereis(nombre_atom) do
      nil ->
        lista = leer_sorteos()

        case Enum.find(lista, fn s -> s.data.nombre == nombre_sorteo end) do
          nil     -> nil
          entrada ->
            pid = ServidorSorteo.iniciar(entrada.data)
            Process.register(pid, nombre_atom)
            pid
        end

      pid -> pid
    end
  end

  defp reanudar_servidores_sorteo do
    leer_sorteos()
    |> Enum.reject(fn s -> s.data.jugado end)
    |> Enum.each(fn entrada ->
      sorteo      = entrada.data
      nombre_atom = String.to_atom(sorteo.nombre)

      unless Process.whereis(nombre_atom) do
        pid = ServidorSorteo.iniciar(sorteo)
        Process.register(pid, nombre_atom)
        IO.puts("[ServidorCentral] ServidorSorteo reanudado: #{sorteo.nombre}")
      end
    end)
  end

  defp calcular_ingresos(sorteo) do
    fracciones     = Map.get(sorteo, :fracciones, 1)
    valor_fraccion = Map.get(sorteo, :valor_fraccion, div(sorteo.valor_billete, max(fracciones, 1)))

    completos =
      sorteo.apuestas
      |> Enum.filter(fn a -> a.tipo == "completo" or a.tipo == :completo end)
      |> Enum.count()
      |> Kernel.*(sorteo.valor_billete)

    por_fraccion =
      sorteo.apuestas
      |> Enum.filter(fn a -> a.tipo == "fraccion" or a.tipo == :fraccion end)
      |> Enum.count()
      |> Kernel.*(valor_fraccion)

    completos + por_fraccion
  end

  defp esperar_respuesta_compra do
    receive do
      {:ok, msg} ->
        receive do
          {:actualizar_sorteo, nuevo_sorteo} -> actualizar_en_json(nuevo_sorteo)
        after 1_000 -> :ok
        end
        {:ok, msg}

      {:error, msg} -> {:error, msg}
    after 5_000 ->
      {:error, "Sin respuesta del servidor de sorteo"}
    end
  end

  # ─────────────────────────────────────────────
  # Bitácora
  # ─────────────────────────────────────────────

  defp registrar_bitacora(accion, detalle, resultado) do
    ts            = timestamp_actual()
    resultado_str = if resultado == :ok, do: "OK", else: "NEGADO"
    linea         = "#{ts} | #{accion} | #{detalle} | #{resultado_str}"

    IO.puts("[BITÁCORA] #{linea}")
    File.write("datos/bitacora.log", linea <> "\n", [:append])
  end

  defp timestamp_actual do
    {{y, m, d}, {h, min, s}} = :calendar.local_time()

    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B", [y, m, d, h, min, s])
    |> to_string()
  end
end
