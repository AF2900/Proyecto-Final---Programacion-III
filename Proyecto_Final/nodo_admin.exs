Mix.install([:jason])

Code.require_file("util.ex", __DIR__)
Code.require_file("modelos/sorteo.ex", __DIR__)
Code.require_file("modelos/cliente.ex", __DIR__)
Code.require_file("modelos/apuesta.ex", __DIR__)
Code.require_file("servidor/servidor_central.ex", __DIR__)

# ─────────────────────────────────────────────────────────────
# nodo_admin.exs — Cliente Administrador
# EJECUTAR: elixir --name admin@127.0.0.1 --cookie loteria_cookie nodo_admin.exs
# ─────────────────────────────────────────────────────────────

nodo_servidor = :"servidor@127.0.0.1"

case Node.connect(nodo_servidor) do
  true  -> IO.puts("✓ Conectado al servidor central")
  false ->
    IO.puts("✗ No se pudo conectar a #{nodo_servidor}")
    IO.puts("  Asegúrese de que nodo_servidor.exs esté corriendo.")
    System.halt(1)
end

defmodule Admin do

  # ─── Menú principal ───────────────────────────────────────
  def menu do
    opcion =
      """

      =================================
         ADMINISTRADOR — SISTEMA LOTERÍA
      =================================
      1.  Crear sorteo
      2.  Listar sorteos
      3.  Ver detalle de sorteo
      4.  Eliminar sorteo
      5.  Ver apuestas de sorteo
      6.  Consultar clientes de sorteo
      7.  Consultar ingresos por sorteo
      8.  Realizar sorteo
      9.  Premios entregados (pasados)
      10. Balance general
      11. Crear premio para sorteo
      12. Listar premios por sorteo
      13. Eliminar premio de sorteo
      0.  Salir
      =================================
      Ingrese una opción:
      """
      |> Util.ingresar(:entero)

    ejecutar_opcion(opcion)
  end

  # ─── Despacho de opciones ─────────────────────────────────

  def ejecutar_opcion(1),  do: crear_sorteo()      |> continuar()
  def ejecutar_opcion(2),  do: listar_sorteos()     |> continuar()
  def ejecutar_opcion(3),  do: ver_detalle_sorteo() |> continuar()
  def ejecutar_opcion(4),  do: eliminar_sorteo()    |> continuar()
  def ejecutar_opcion(5),  do: ver_apuestas()       |> continuar()
  def ejecutar_opcion(6),  do: consultar_clientes() |> continuar()
  def ejecutar_opcion(7),  do: consultar_ingresos() |> continuar()
  def ejecutar_opcion(8),  do: realizar_sorteo()    |> continuar()
  def ejecutar_opcion(9),  do: premios_pasados()    |> continuar()
  def ejecutar_opcion(10), do: balance_general()    |> continuar()
  def ejecutar_opcion(11), do: crear_premio()       |> continuar()
  def ejecutar_opcion(12), do: listar_premios()     |> continuar()
  def ejecutar_opcion(13), do: eliminar_premio()    |> continuar()

  def ejecutar_opcion(0) do
    Util.mostrar_mensaje("Saliendo del sistema...")
  end

  def ejecutar_opcion(_) do
    Util.mostrar_error("Opción inválida")
    menu()
  end

  defp continuar(_), do: menu()

  # ─── 1. Crear sorteo ──────────────────────────────────────
  defp crear_sorteo do
    nombre     = "Ingrese el nombre del sorteo: "        |> Util.ingresar(:texto)
    fecha      = "Ingrese la fecha (YYYY-MM-DD): "       |> Util.ingresar(:texto)
    valor      = "Ingrese valor del billete: "            |> Util.ingresar(:entero)
    fracciones = "Cantidad de fracciones por billete: "  |> Util.ingresar(:entero)
    cantidad   = "Cantidad de billetes: "                 |> Util.ingresar(:entero)

    case ServidorCentral.llamar_servidor(:crear_sorteo, [nombre, fecha, valor, fracciones, cantidad]) do
      {:ok, msg}    -> Util.mostrar_mensaje(msg)
      {:error, msg} -> Util.mostrar_error(msg)
    end
  end

  # ─── 2. Listar sorteos ────────────────────────────────────
  defp listar_sorteos do
    case ServidorCentral.llamar_servidor(:listar_sorteos) do
      {:ok, []} ->
        Util.mostrar_mensaje("No hay sorteos registrados")

      {:ok, lista} ->
        Enum.each(lista, fn s ->
          sorteo = s.data
          IO.puts("---------------------------")
          IO.puts("Nombre:     #{sorteo.nombre}")
          IO.puts("Fecha:      #{sorteo.fecha}")
          IO.puts("Valor:      $#{sorteo.valor_billete}")
          IO.puts("Fracciones: #{Map.get(sorteo, :fracciones, 1)} (c/u $#{Map.get(sorteo, :valor_fraccion, sorteo.valor_billete)})")

          premios = Map.get(sorteo, :premios, [])
          if premios != [] do
            IO.puts("Premios:")
            Enum.each(premios, fn p -> IO.puts("  • #{p.nombre}: $#{p.valor}") end)
          end

          if sorteo.jugado do
            IO.puts("Estado:     FINALIZADO")
            IO.puts("Ganador:    Billete ##{sorteo.ganador}")
          else
            IO.puts("Estado:     ACTIVO")
          end
        end)

      {:error, msg} ->
        Util.mostrar_error(msg)
    end
  end

  # ─── 3. Ver detalle ───────────────────────────────────────
  defp ver_detalle_sorteo do
    nombre = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)

    case ServidorCentral.llamar_servidor(:ver_detalle_sorteo, [nombre]) do
      {:ok, sorteo} ->
        IO.puts("----- DETALLE DEL SORTEO -----")
        IO.puts("Nombre:     #{sorteo.nombre}")
        IO.puts("Fecha:      #{sorteo.fecha}")
        IO.puts("Valor:      $#{sorteo.valor_billete}")
        IO.puts("Fracciones: #{Map.get(sorteo, :fracciones, 1)} (c/u $#{Map.get(sorteo, :valor_fraccion, sorteo.valor_billete)})")

        premios = Map.get(sorteo, :premios, [])
        if premios != [] do
          IO.puts("Premios:")
          Enum.each(premios, fn p -> IO.puts("  • #{p.nombre}: $#{p.valor}") end)
        end

        if sorteo.jugado do
          IO.puts("Estado:     FINALIZADO")
          IO.puts("Ganador:    Billete ##{sorteo.ganador}")
        else
          IO.puts("Estado:     ACTIVO")
        end

      {:error, msg} ->
        Util.mostrar_error(msg)
    end
  end

  # ─── 4. Eliminar sorteo ───────────────────────────────────
  defp eliminar_sorteo do
    nombre = "Ingrese el nombre del sorteo a eliminar: " |> Util.ingresar(:texto)

    case ServidorCentral.llamar_servidor(:eliminar_sorteo, [nombre]) do
      {:ok, msg}    -> Util.mostrar_mensaje(msg)
      {:error, msg} -> Util.mostrar_error(msg)
    end
  end

  # ─── 5. Ver apuestas ──────────────────────────────────────
  defp ver_apuestas do
    nombre = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)

    case ServidorCentral.llamar_servidor(:ver_apuestas, [nombre]) do
      {:ok, []} ->
        Util.mostrar_mensaje("No hay apuestas registradas")

      {:ok, apuestas} ->
        Enum.with_index(apuestas, 1)
        |> Enum.each(fn {a, i} ->
          tipo = if a.tipo == :fraccion or a.tipo == "fraccion",
            do: "fracción ##{a.fraccion}",
            else: "billete completo"
          IO.puts("#{i}. #{a.cliente.nombre} — billete ##{a.numero} (#{tipo})")
        end)

      {:error, msg} ->
        Util.mostrar_error(msg)
    end
  end

  # ─── 6. Consultar clientes agrupados ─────────────────────
  defp consultar_clientes do
    nombre = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)

    case ServidorCentral.llamar_servidor(:consultar_clientes, [nombre]) do
      {:ok, %{completos: completos, fracciones: fracciones}} ->
        IO.puts("\n── Compradores de billete completo ──")
        if completos == [] do
          IO.puts("  (ninguno)")
        else
          Enum.each(completos, fn a ->
            IO.puts("  • #{a.cliente.nombre} — billete ##{a.numero}")
          end)
        end

        IO.puts("\n── Compradores por fracción ──")
        if fracciones == [] do
          IO.puts("  (ninguno)")
        else
          Enum.each(fracciones, fn a ->
            IO.puts("  • #{a.cliente.nombre} — billete ##{a.numero} fracción ##{a.fraccion}")
          end)
        end

      {:error, msg} ->
        Util.mostrar_error(msg)
    end
  end

# ─── 7. Consultar ingresos ────────────────────────────────
defp consultar_ingresos do
  nombre = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)

  case ServidorCentral.llamar_servidor(:consultar_ingresos, [nombre]) do
    {:ok, total} when is_integer(total) ->
      IO.puts("\n── Ingresos del sorteo '#{nombre}' ──")
      IO.puts("  Total recaudado: $#{total}")

    {:error, msg} ->
      Util.mostrar_error(msg)
  end
end

  # ─── 8. Realizar sorteo ───────────────────────────────────
  defp realizar_sorteo do
    nombre = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)

    case ServidorCentral.llamar_servidor(:realizar_sorteo, [nombre]) do
      {:ok, msg}    -> Util.mostrar_mensaje(msg)
      {:error, msg} -> Util.mostrar_error(msg)
    end
  end

  # ─── 9. Premios entregados en sorteos pasados ─────────────
  defp premios_pasados do
    case ServidorCentral.llamar_servidor(:consultar_premios_pasados) do
      {:ok, []} ->
        Util.mostrar_mensaje("No hay sorteos finalizados")

      {:ok, lista} ->
        Enum.each(lista, fn s ->
          IO.puts("\n===== #{s.nombre} =====")
          IO.puts("Dinero recolectado: $#{s.dinero_recolectado}")

          if s.premios == [] do
            IO.puts("Premios: (ninguno)")
          else
            IO.puts("Premios entregados:")
            Enum.each(s.premios, fn p -> IO.puts("  • #{p.nombre}: $#{p.valor}") end)
          end

          if s.ganadores == [] do
            IO.puts("Ganadores: (ninguno registrado)")
          else
            IO.puts("Ganadores: #{Enum.join(s.ganadores, ", ")}")
          end

          balance_str = if s.balance >= 0, do: "+$#{s.balance} (ganancia)", else: "-$#{abs(s.balance)} (pérdida)"
          IO.puts("Balance:   #{balance_str}")
        end)

      {:error, msg} ->
        Util.mostrar_error(msg)
    end
  end

  # ─── 10. Balance general ──────────────────────────────────
  defp balance_general do
    case ServidorCentral.llamar_servidor(:consultar_balance) do
      {:ok, %{detalle: [], total: _}} ->
        Util.mostrar_mensaje("No hay sorteos finalizados")

      {:ok, %{detalle: detalle, total: total}} ->
        IO.puts("\n── Balance por sorteo ──")
        Enum.each(detalle, fn d ->
          balance_str = if d.balance >= 0, do: "+$#{d.balance}", else: "-$#{abs(d.balance)}"
          IO.puts("  #{d.nombre} (#{d.fecha}) — Ingresos: $#{d.ingresos} | Premios: $#{d.premios} | Balance: #{balance_str}")
        end)

        IO.puts("\n── Total acumulado ──")
        total_str = if total >= 0, do: "+$#{total} (ganancia)", else: "-$#{abs(total)} (pérdida)"
        IO.puts("  #{total_str}")

      {:error, msg} ->
        Util.mostrar_error(msg)
    end
  end

  # ─── 11. Crear premio ─────────────────────────────────────
  defp crear_premio do
    nombre_sorteo = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)
    nombre_premio = "Nombre del premio: "             |> Util.ingresar(:texto)
    valor         = "Valor del premio: "              |> Util.ingresar(:entero)

    case ServidorCentral.llamar_servidor(:crear_premio, [nombre_sorteo, nombre_premio, valor]) do
      {:ok, msg}    -> Util.mostrar_mensaje(msg)
      {:error, msg} -> Util.mostrar_error(msg)
    end
  end

  # ─── 12. Listar premios por sorteo ────────────────────────
  defp listar_premios do
    case ServidorCentral.llamar_servidor(:listar_premios) do
      {:ok, []} ->
        Util.mostrar_mensaje("No hay sorteos registrados")

      {:ok, lista} ->
        Enum.each(lista, fn entry ->
          IO.puts("\n===== #{entry.sorteo} (#{entry.fecha}) =====")
          if entry.premios == [] do
            IO.puts("  (sin premios)")
          else
            Enum.each(entry.premios, fn p ->
              IO.puts("  • #{p.nombre}: $#{p.valor}")
            end)
          end
        end)

      {:error, msg} ->
        Util.mostrar_error(msg)
    end
  end

  # ─── 13. Eliminar premio ──────────────────────────────────
  defp eliminar_premio do
    nombre_sorteo = "Ingrese el nombre del sorteo: "           |> Util.ingresar(:texto)
    nombre_premio = "Ingrese el nombre del premio a eliminar: " |> Util.ingresar(:texto)

    case ServidorCentral.llamar_servidor(:eliminar_premio, [nombre_sorteo, nombre_premio]) do
      {:ok, msg}    -> Util.mostrar_mensaje(msg)
      {:error, msg} -> Util.mostrar_error(msg)
    end
  end
end

Admin.menu()
