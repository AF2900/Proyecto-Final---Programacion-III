defmodule ServidorCentral do
  @ruta "datos/sorteos.json"

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

  def realizar_sorteo do
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

              send(pid, {:realizar_sorteo, self(), self()})

              receive do
                {:ok, msg} ->
                  IO.puts(msg)

                  receive do
                    {:actualizar_sorteo, nuevo_sorteo} ->
                      actualizar_en_json(nuevo_sorteo)
                  after
                    1000 -> :ok
                  end

                {:error, msg} ->
                  IO.puts(msg)
              after
                2000 ->
                  IO.puts("Sin respuesta del proceso")
              end
          end
        end

      _ ->
        Util.mostrar_error("Error")
    end
  end

  defp intentar_compra(pid, cliente) do
    numero = "Ingrese número de billete: " |> Util.ingresar(:entero)

    send(pid, {:comprar, cliente, numero, self(), self()})

    receive do
      {:ok, msg} ->
        IO.puts(msg)

        receive do
          {:actualizar_sorteo, nuevo_sorteo} ->
            actualizar_en_json(nuevo_sorteo)
        after
          1000 -> :ok
        end

      {:error, msg} ->
        IO.puts(msg)
        intentar_compra(pid, cliente)
    after
      2000 ->
        IO.puts("Sin respuesta")
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

  def ver_apuestas do
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

              send(pid, {:obtener_apuestas, self()})

              receive do
                {:apuestas, apuestas} ->
                  if apuestas == [] do
                    IO.puts("No hay apuestas registradas")
                  else
                    Enum.with_index(apuestas)
                    |> Enum.each(fn {a, i} ->
                      IO.puts("#{i + 1}. #{a.cliente.nombre} compró el billete #{a.numero}")
                    end)
                  end
              after
                2000 ->
                  IO.puts("No hubo respuesta del proceso")
              end
          end
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

  def eliminar_sorteo do
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

          opcion = "Seleccione sorteo a eliminar: " |> Util.ingresar(:entero)
          seleccionado = Enum.at(lista, opcion - 1)

          case seleccionado do
            nil ->
              Util.mostrar_error("Opción inválida")

            _ ->
              sorteo = seleccionado.data

              if sorteo.jugado do
                nueva_lista =
                  Enum.filter(lista, fn s ->
                    s.data.nombre != sorteo.nombre
                  end)

                File.write!(@ruta, Jason.encode!(nueva_lista, pretty: true))

                nombre_proceso = String.to_atom(sorteo.nombre)

                if Process.whereis(nombre_proceso) do
                  Process.unregister(nombre_proceso)
                end

                Util.mostrar_mensaje("Sorteo eliminado correctamente")
              else
                Util.mostrar_error("Solo se pueden eliminar sorteos finalizados")
              end
          end
        end

      _ ->
        Util.mostrar_error("Error al leer datos")
    end
  end
end
