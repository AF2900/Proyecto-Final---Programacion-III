Code.require_file("../modelos/sorteo.ex", __DIR__)
Code.require_file("servidor_sorteo.ex", __DIR__)
Code.require_file("../modelos/cliente.ex", __DIR__)

defmodule ServidorCentral do
  @ruta "datos/sorteos.json"

  def crear_sorteo do
    nombre =
      "Ingrese el nombre del sorteo: "
      |> Util.ingresar(:texto)

    fecha =
      "Ingrese la fecha: "
      |> Util.ingresar(:texto)

    valor =
      "Ingrese valor del billete: "
      |> Util.ingresar(:entero)

    cantidad =
      "Ingrese cantidad de billetes: "
      |> Util.ingresar(:entero)

    sorteo = Sorteo.crear(nombre, fecha, valor, cantidad)

    pid = spawn(fn -> ServidorSorteo.iniciar(sorteo) end)

    send(pid, {:obtener_info, self()})

    receive do
      {:respuesta, _} ->
        IO.puts("Proceso del sorteo activo correctamente")
    after
      1000 ->
        IO.puts("Proceso no respondió")
    end

    guardar_sorteo(%{
      data: sorteo,
      pid: inspect(pid)
    })

    "Sorteo creado correctamente"
    |> Util.mostrar_mensaje()
  end

  def listar_sorteos do
    case File.read(@ruta) do
      {:ok, contenido} ->
        lista = Jason.decode!(contenido, keys: :atoms)

        if lista == [] do
          "No hay sorteos registrados"
          |> Util.mostrar_mensaje()
        else
          Enum.each(lista, fn s ->
            sorteo = s.data

            IO.puts("---------------------------")
            IO.puts("Nombre: #{sorteo.nombre}")
            IO.puts("Fecha: #{sorteo.fecha}")
            IO.puts("Valor: #{sorteo.valor_billete}")
            IO.puts("PID: #{s.pid}")
          end)
        end

      _ ->
        "No hay sorteos registrados"
        |> Util.mostrar_mensaje()
    end
  end

  defp guardar_sorteo(sorteo) do
    lista =
      case File.read(@ruta) do
        {:ok, contenido} -> Jason.decode!(contenido, keys: :atoms)
        _ -> []
      end

    nueva_lista = [sorteo | lista]

    File.write!(@ruta, Jason.encode!(nueva_lista, pretty: true))
  end

  def comprar_billete do
    case File.read(@ruta) do
      {:ok, contenido} ->
        lista = Jason.decode!(contenido, keys: :atoms)

        if lista == [] do
          "No hay sorteos"
          |> Util.mostrar_mensaje()
        else
          lista
          |> Enum.with_index()
          |> Enum.each(fn {s, i} ->
            IO.puts("#{i + 1}. #{s.data.nombre}")
          end)

          opcion =
            "Seleccione sorteo: "
            |> Util.ingresar(:entero)

          seleccionado = Enum.at(lista, opcion - 1)
          sorteo = seleccionado.data

          cliente = Cliente.ingresar()

          pid = spawn(fn -> ServidorSorteo.iniciar(sorteo) end)

          intentar_compra(pid, cliente)
        end

      _ ->
        Util.mostrar_error("Error")
    end
  end

  def ver_detalle_sorteo do
    case File.read(@ruta) do
      {:ok, contenido} ->
        lista = Jason.decode!(contenido, keys: :atoms)

        if lista == [] do
          "No hay sorteos registrados"
          |> Util.mostrar_mensaje()
        else
          lista
          |> Enum.with_index()
          |> Enum.each(fn {s, i} ->
            sorteo = s.data
            IO.puts("#{i + 1}. #{sorteo.nombre}")
          end)

          opcion =
            "Seleccione un sorteo: "
            |> Util.ingresar(:entero)

          seleccionado = Enum.at(lista, opcion - 1)

          sorteo = seleccionado.data

          IO.puts("----- DETALLE DEL SORTEO -----")
          IO.puts("Nombre: #{sorteo.nombre}")
          IO.puts("Fecha: #{sorteo.fecha}")
          IO.puts("Valor: #{sorteo.valor_billete}")
        end

      _ ->
        "Error al leer datos"
        |> Util.mostrar_error()
    end
  end

  defp intentar_compra(pid, cliente) do
    numero =
      "Ingrese número de billete: "
      |> Util.ingresar(:entero)

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
end
