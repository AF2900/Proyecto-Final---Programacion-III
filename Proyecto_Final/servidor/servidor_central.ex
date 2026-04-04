Code.require_file("../modelos/sorteo.ex", __DIR__)

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

    guardar_sorteo(sorteo)

    "Sorteo creado correctamente"
    |> Util.mostrar_mensaje()
  end

  def listar_sorteos do
    case File.read(@ruta) do
      {:ok, contenido} ->
        lista = Jason.decode!(contenido)

        if lista == [] do
          "No hay sorteos registrados"
          |> Util.mostrar_mensaje()
        else
          Enum.each(lista, fn s ->
            IO.puts("---------------------------")
            IO.puts("Nombre: #{s["nombre"]}")
            IO.puts("Fecha: #{s["fecha"]}")
            IO.puts("Valor: #{s["valor_billete"]}")
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
        {:ok, contenido} -> Jason.decode!(contenido)
        _ -> []
      end

    nueva_lista = [sorteo | lista]

    File.write!(@ruta, Jason.encode!(nueva_lista, pretty: true))
  end
end
