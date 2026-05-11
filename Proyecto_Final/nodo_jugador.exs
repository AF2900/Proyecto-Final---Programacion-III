Mix.install([:jason])

Code.require_file("util.ex", __DIR__)
Code.require_file("modelos/sorteo.ex", __DIR__)
Code.require_file("modelos/cliente.ex", __DIR__)
Code.require_file("modelos/apuesta.ex", __DIR__)
Code.require_file("servidor/servidor_central.ex", __DIR__)

# ─────────────────────────────────────────────────────────────
# nodo_jugador.exs
# EJECUTAR: elixir --name jugador@127.0.0.1 --cookie loteria_cookie nodo_jugador.exs
# ─────────────────────────────────────────────────────────────

nodo_servidor = :"servidor@127.0.0.1"

case Node.connect(nodo_servidor) do
  true ->
    IO.puts("✓ Conectado al servidor")
  false ->
    IO.puts("✗ No se pudo conectar a #{nodo_servidor}")
    IO.puts("  Asegúrese de que nodo_servidor.exs esté corriendo.")
    System.halt(1)
end

defmodule Jugador do

  # ─── Menú principal ───────────────────────────────────────
  def menu do
    opcion =
      """
      =========================
         JUGADOR
      =========================
      1. Ver sorteos disponibles
      2. Ver apuestas de un sorteo
      3. Comprar billete completo
      4. Comprar fracción de billete
      5. Ver billetes y fracciones disponibles
      6. Devolver compra
      0. Salir
      =========================
      Ingrese una opción:
      """
      |> Util.ingresar(:entero)

    ejecutar_opcion(opcion)
  end

  # ─── Opciones ─────────────────────────────────────────────

  def ejecutar_opcion(1) do
    ver_sorteos_disponibles()
    menu()
  end

  def ejecutar_opcion(2) do
    ver_apuestas()
    menu()
  end

  def ejecutar_opcion(3) do
    comprar_billete()
    menu()
  end

  def ejecutar_opcion(4) do
    comprar_fraccion()
    menu()
  end

  def ejecutar_opcion(5) do
    ver_disponibles()
    menu()
  end

  def ejecutar_opcion(6) do
    devolver_compra()
    menu()
  end

  def ejecutar_opcion(0) do
    Util.mostrar_mensaje("Saliendo del sistema...")
  end

  def ejecutar_opcion(_) do
    Util.mostrar_error("Opción inválida")
    menu()
  end

  # ─── 1. Ver sorteos disponibles ───────────────────────────
  defp ver_sorteos_disponibles do
    case ServidorCentral.llamar_servidor(:listar_sorteos) do
      {:ok, lista} ->
        disponibles = Enum.reject(lista, fn s -> s.data.jugado end)

        if disponibles == [] do
          Util.mostrar_mensaje("No hay sorteos disponibles")
        else
          Enum.each(disponibles, fn s ->
            sorteo = s.data
            IO.puts("---------------------------")
            IO.puts("Nombre: #{sorteo.nombre}")
            IO.puts("Fecha:  #{sorteo.fecha}")
            IO.puts("Valor:  $#{sorteo.valor_billete}")
            IO.puts("Fracciones: #{Map.get(sorteo, :fracciones, 1)} (c/u $#{Map.get(sorteo, :valor_fraccion, sorteo.valor_billete)})")
          end)
        end

      {:error, msg} ->
        Util.mostrar_error(msg)
    end
  end

  # ─── 2. Ver apuestas de un sorteo ─────────────────────────
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

  # ─── 3. Comprar billete completo ──────────────────────────
  defp comprar_billete do
    nombre_sorteo = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)
    cliente       = Cliente.ingresar()
    numero        = "Ingrese número de billete: "    |> Util.ingresar(:entero)

    case ServidorCentral.llamar_servidor(:comprar_billete, [nombre_sorteo, cliente, numero]) do
      {:ok, msg}    -> Util.mostrar_mensaje(msg)
      {:error, msg} -> Util.mostrar_error(msg)
    end
  end

  # ─── 4. Comprar fracción de billete ───────────────────────
defp comprar_fraccion do
  nombre_sorteo = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)

  # Consultar disponibles antes de pedir el billete
  case ServidorCentral.llamar_servidor(:consultar_disponibles, [nombre_sorteo]) do
    {:error, msg} ->
      Util.mostrar_error(msg)

    {:ok, %{fracciones: []}} ->
      Util.mostrar_mensaje("No hay fracciones disponibles en este sorteo")

    {:ok, %{fracciones: fracciones}} ->
      # Mostrar billetes que tienen fracciones disponibles
      billetes_con_fracciones =
        fracciones
        |> Enum.map(fn f -> f.billete end)
        |> Enum.uniq()
        |> Enum.sort()

      IO.puts("\n── Billetes con fracciones disponibles ──")
      IO.puts("  " <> Enum.join(Enum.map(billetes_con_fracciones, &"##{&1}"), ", "))

      numero_billete = "Ingrese número de billete: " |> Util.ingresar(:entero)

      # Mostrar fracciones disponibles para ese billete
      fracciones_del_billete =
        fracciones
        |> Enum.filter(fn f -> f.billete == numero_billete end)
        |> Enum.map(fn f -> f.fraccion end)
        |> Enum.sort()

      if fracciones_del_billete == [] do
        Util.mostrar_error("No hay fracciones disponibles para el billete ##{numero_billete}")
      else
        IO.puts("\n── Fracciones disponibles para billete ##{numero_billete} ──")
        IO.puts("  " <> Enum.join(Enum.map(fracciones_del_billete, &"##{&1}"), ", "))

        numero_fraccion = "Ingrese número de fracción: " |> Util.ingresar(:entero)
        cliente         = Cliente.ingresar()

        case ServidorCentral.llamar_servidor(:comprar_fraccion, [nombre_sorteo, cliente, numero_billete, numero_fraccion]) do
          {:ok, msg}    -> Util.mostrar_mensaje(msg)
          {:error, msg} -> Util.mostrar_error(msg)
        end
      end
  end
end

  # ─── 5. Ver billetes y fracciones disponibles ─────────────
  defp ver_disponibles do
    nombre_sorteo = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)

    case ServidorCentral.llamar_servidor(:consultar_disponibles, [nombre_sorteo]) do
      {:ok, %{completos: completos, fracciones: fracciones}} ->
        IO.puts("\n── Billetes completos disponibles ──")
        if completos == [] do
          IO.puts("  (ninguno disponible)")
        else
          IO.puts("  " <> Enum.join(Enum.map(completos, &"##{&1}"), ", "))
        end

        IO.puts("\n── Fracciones disponibles ──")
        if fracciones == [] do
          IO.puts("  (ninguna disponible)")
        else
          Enum.each(fracciones, fn f ->
            IO.puts("  Billete ##{f.billete} — Fracción ##{f.fraccion}")
          end)
        end

      {:error, msg} ->
        Util.mostrar_error(msg)
    end
  end

  # ─── 6. Devolver compra ───────────────────────────────────
  defp devolver_compra do
    nombre_sorteo  = "Ingrese el nombre del sorteo: " |> Util.ingresar(:texto)
    nombre_cliente = "Ingrese su nombre: "             |> Util.ingresar(:texto)
    numero_billete = "Ingrese número de billete: "     |> Util.ingresar(:entero)

    tipo =
      "Tipo de compra (completo / fraccion): "
      |> Util.ingresar(:texto)
      |> String.downcase()
      |> String.trim()

    numero_fraccion =
      if tipo == "fraccion" do
        "Ingrese número de fracción: " |> Util.ingresar(:entero)
      else
        nil
      end

    case ServidorCentral.llamar_servidor(:devolver_compra, [nombre_sorteo, nombre_cliente, numero_billete, tipo, numero_fraccion]) do
      {:ok, msg}    -> Util.mostrar_mensaje(msg)
      {:error, msg} -> Util.mostrar_error(msg)
    end
  end
end

Jugador.menu()
