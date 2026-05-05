Code.require_file("../modelos/sorteo.ex", __DIR__)
Code.require_file("servidor_sorteo.ex", __DIR__)
Code.require_file("../modelos/cliente.ex", __DIR__)

defmodule ServidorCentral do
  @ruta "datos/sorteos.json"

  # =========================
  # CREAR SORTEO
  # =========================
  def crear_sorteo do
    nombre = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)
    fecha = "Ingrese la fecha: " |> Util.ingresar(:texto)
    valor = "Ingrese valor del billete: " |> Util.ingresar(:entero)
    cantidad = "Ingrese cantidad de billetes: " |> Util.ingresar(:entero)

    sorteo = Sorteo.crear(nombre, fecha, valor, cantidad)

    pid = ServidorSorteo.iniciar(sorteo)
    Process.register(pid, String.to_atom(nombre))

    guardar_sorteo(%{data: sorteo})

    Util.mostrar_mensaje("Sorteo creado correctamente")
  end

  # =========================
  # LISTAR SORTEOS
  # =========================
  def listar_sorteos do
    case File.read(@ruta) do
      {:ok, contenido} ->
        lista = Jason.decode!(contenido, keys: :atoms)

        if lista == [] do
          Util.mostrar_mensaje("No hay sorteos registrados")
        else
          Enum.each(lista, fn s ->
            sorteo = s.data

            IO.puts("---------------------------")
            IO.puts("Nombre: #{sorteo.nombre}")
            IO.puts("Fecha: #{sorteo.fecha}")
            IO.puts("Valor: #{sorteo.valor_billete}")
          end)
        end

      _ ->
        Util.mostrar_mensaje("No hay sorteos registrados")
    end
  end

  # =========================
  # GUARDAR
  # =========================
  defp guardar_sorteo(sorteo) do
    lista =
      case File.read(@ruta) do
        {:ok, contenido} -> Jason.decode!(contenido, keys: :atoms)
        _ -> []
      end

    nueva_lista = [sorteo | lista]
    File.write!(@ruta, Jason.encode!(nueva_lista, pretty: true))
  end

  # =========================
  # COMPRAR BILLETE
  # =========================
  def comprar_billete do
    case File.read(@ruta) do
      {:ok, contenido} ->
        lista = Jason.decode!(contenido, keys: :atoms)

        if lista == [] do
          Util.mostrar_mensaje("No hay sorteos")
        else
          Enum.with_index(lista)
          |> Enum.each(fn {s, i} ->
            IO.puts("#{i + 1}. #{s.data.nombre}")
          end)

          opcion = "Seleccione sorteo: " |> Util.ingresar(:entero)
          seleccionado = Enum.at(lista, opcion - 1)

          case seleccionado do
            nil ->
              Util.mostrar_error("Opción inválida")

            _ ->
              cliente = Cliente.ingresar()
              sorteo = seleccionado.data
              nombre_proceso = String.to_atom(sorteo.nombre)

              pid =
                case Process.whereis(nombre_proceso) do
                  nil ->
                    nuevo = ServidorSorteo.iniciar(sorteo)
                    Process.register(nuevo, nombre_proceso)
                    nuevo

                  existente ->
                    existente
                end

              intentar_compra(pid, cliente)
          end
        end

      _ ->
        Util.mostrar_error("Error")
    end
  end

  # =========================
  # INTENTAR COMPRA
  # =========================
  defp intentar_compra(pid, cliente) do
    numero = "Ingrese número de billete: " |> Util.ingresar(:entero)

    send(pid, {:comprar, cliente, numero, self()})

    receive do
      {:ok, msg} ->
        IO.puts(msg)

      {:error, msg} ->
        IO.puts(msg)
        intentar_compra(pid, cliente)
    after
      2000 ->
        IO.puts("Sin respuesta")
    end
  end

  # =========================
  # VER DETALLE
  # =========================
  def ver_detalle_sorteo do
    case File.read(@ruta) do
      {:ok, contenido} ->
        lista = Jason.decode!(contenido, keys: :atoms)

        if lista == [] do
          Util.mostrar_mensaje("No hay sorteos")
        else
          Enum.with_index(lista)
          |> Enum.each(fn {s, i} ->
            IO.puts("#{i + 1}. #{s.data.nombre}")
          end)

          opcion = "Seleccione un sorteo: " |> Util.ingresar(:entero)
          seleccionado = Enum.at(lista, opcion - 1)

          case seleccionado do
            nil ->
              Util.mostrar_error("Opción inválida")

            _ ->
              sorteo = seleccionado.data

              IO.puts("----- DETALLE DEL SORTEO -----")
              IO.puts("Nombre: #{sorteo.nombre}")
              IO.puts("Fecha: #{sorteo.fecha}")
              IO.puts("Valor: #{sorteo.valor_billete}")

              if sorteo.jugado do
                IO.puts("Estado: FINALIZADO")
                IO.puts("Número ganador: #{sorteo.ganador}")
              else
                IO.puts("Estado: ACTIVO")
              end
          end
        end

      _ ->
        Util.mostrar_error("Error al leer datos")
    end
  end

  # =========================
  # ACTUALIZAR JSON
  # =========================
  defp actualizar_en_json(nuevo_sorteo) do
    lista =
      case File.read(@ruta) do
        {:ok, contenido} -> Jason.decode!(contenido, keys: :atoms)
        _ -> []
      end

    nueva_lista =
      Enum.map(lista, fn s ->
        if s.data.nombre == nuevo_sorteo.nombre do
          %{s | data: nuevo_sorteo}
        else
          s
        end
      end)

    File.write!(@ruta, Jason.encode!(nueva_lista, pretty: true))
  end
end
