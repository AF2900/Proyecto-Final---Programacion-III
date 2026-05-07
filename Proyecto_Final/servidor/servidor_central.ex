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
                  esperar_respuestas()

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
        esperar_respuestas()

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
              IO.puts("Ingresos: $#{Map.get(sorteo, :ingresos, 0)}")

              IO.puts("----- PREMIOS -----")

              if sorteo.premios == [] do
                IO.puts("Sin premios")
              else
                Enum.each(sorteo.premios, fn p ->
                  IO.puts("#{p.nombre} - $#{p.valor}")
                end)
              end

              if sorteo.jugado do
                IO.puts("Estado: FINALIZADO")
                IO.puts("Número ganador: #{sorteo.ganador}")

                if sorteo.premio_ganado do
                  IO.puts(
                    "Premio: #{sorteo.premio_ganado.nombre} ($#{sorteo.premio_ganado.valor})"
                  )
                end

                IO.puts("Balance: $#{Map.get(sorteo, :balance, 0)}")

                ganador =
                  Enum.find(sorteo.apuestas, fn a ->
                    a.numero == sorteo.ganador
                  end)

                if ganador do
                  IO.puts("----- GANADOR -----")
                  IO.puts("Nombre: #{ganador.cliente.nombre}")
                  IO.puts("Documento: #{ganador.cliente.documento}")
                  IO.puts("Tarjeta: #{ganador.cliente.tarjeta}")
                end
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

  defp esperar_respuestas() do
    esperar_respuestas(false)
  end

  defp esperar_respuestas(actualizado?) do
    receive do
      {:actualizar_sorteo, nuevo_sorteo} ->
        actualizar_en_json(nuevo_sorteo)
        :ok

      {:premio_agregado, msg} ->
        Util.mostrar_mensaje(msg)

        if actualizado? do
          :ok
        else
          esperar_respuestas(actualizado?)
        end

      {:premio_eliminado, msg} ->
        Util.mostrar_mensaje(msg)

        if actualizado? do
          :ok
        else
          esperar_respuestas(actualizado?)
        end

      {:error, msg} ->
        Util.mostrar_error(msg)
    end
  end

  def crear_premio do
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
              nombre = "Nombre del premio: " |> Util.ingresar(:texto)
              valor = "Valor del premio: " |> Util.ingresar(:entero)

              premio = %{
                nombre: nombre,
                valor: valor
              }

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

              send(pid, {:agregar_premio, premio, self()})

              esperar_respuestas()
          end
        end

      _ ->
        Util.mostrar_error("Error")
    end
  end

  def listar_premios do
    case File.read(@ruta) do
      {:ok, contenido} ->
        lista = Jason.decode!(contenido, keys: :atoms)

        Enum.each(lista, fn s ->
          sorteo = s.data

          IO.puts("----- #{sorteo.nombre} -----")

          if sorteo.premios == [] do
            IO.puts("Sin premios")
          else
            Enum.each(sorteo.premios, fn p ->
              IO.puts("#{p.nombre} - $#{p.valor}")
            end)
          end
        end)

      _ ->
        Util.mostrar_error("Error")
    end
  end

  def clientes_ordenados do
    case File.read(@ruta) do
      {:ok, contenido} ->
        lista = Jason.decode!(contenido, keys: :atoms)

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
            apuestas = seleccionado.data.apuestas

            if apuestas == [] do
              IO.puts("No hay Clientes aún")
            else
              clientes_ordenados =
                apuestas
                |> Enum.map(fn a -> a.cliente end)
                |> Enum.uniq_by(fn c -> c.documento end)
                |> Enum.sort_by(fn c ->
                  -Enum.count(apuestas, fn a -> a.cliente.documento == c.documento end)
                end)

              IO.puts("----- CLIENTES ORDENADOS -----")

              Enum.each(clientes_ordenados, fn c ->
                cantidad =
                  apuestas
                  |> Enum.filter(fn a -> a.cliente.documento == c.documento end)
                  |> length()

                IO.puts("----------------------")
                IO.puts("Nombre: #{c.nombre}")
                IO.puts("Documento: #{c.documento}")
                IO.puts("Billetes comprados: #{cantidad}")
              end)
            end
        end

      _ ->
        Util.mostrar_error("Error")
    end
  end

  def historial_sorteo do
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
              apuestas = seleccionado.data.apuestas

              IO.puts("----- HISTORIAL -----")

              if apuestas == [] do
                IO.puts("No hay historial")
              else
                Enum.each(apuestas, fn a ->
                  IO.puts("----------------------")
                  IO.puts("Cliente: #{a.cliente.nombre}")
                  IO.puts("Documento: #{a.cliente.documento}")
                  IO.puts("Billete: #{a.numero}")
                end)

                total = length(apuestas) * seleccionado.data.valor_billete
                IO.puts("----------------------")
                IO.puts("Total recaudado: $#{total}")
              end
          end
        end

      _ ->
        Util.mostrar_error("Error")
    end
  end

  def eliminar_premio do
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

              if sorteo.premios == [] do
                Util.mostrar_mensaje("No hay premios para eliminar")
              else
                Enum.with_index(sorteo.premios)
                |> Enum.each(fn {p, i} ->
                  IO.puts("#{i + 1}. #{p.nombre} - $#{p.valor}")
                end)

                indice =
                  "Seleccione premio a eliminar: "
                  |> Util.ingresar(:entero)

                if indice < 1 or indice > length(sorteo.premios) do
                  Util.mostrar_error("Índice inválido")
                else
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

                  send(pid, {:eliminar_premio, indice - 1, self()})

                  esperar_respuestas()
                end
              end
          end
        end

      _ ->
        Util.mostrar_error("Error")
    end
  end

  def resumen_jugadores do
    case File.read(@ruta) do
      {:ok, contenido} ->
        lista = Jason.decode!(contenido, keys: :atoms)

        jugadores =
          lista
          |> Enum.flat_map(fn s ->
            Enum.map(s.data.apuestas, fn a ->
              %{
                nombre: a.cliente.nombre,
                documento: a.cliente.documento,
                gasto: s.data.valor_billete,
                gano:
                  if s.data.jugado and a.numero == s.data.ganador do
                    Map.get(s.data.premio_ganado, :valor, 0)
                  else
                    0
                  end
              }
            end)
          end)

        agrupados =
          jugadores
          |> Enum.group_by(& &1.documento)

        IO.puts("----- RESUMEN DE JUGADORES -----")

        Enum.each(agrupados, fn {_doc, lista_jugador} ->
          nombre = hd(lista_jugador).nombre

          total_gasto =
            Enum.reduce(lista_jugador, 0, fn j, acc -> acc + j.gasto end)

          total_ganado =
            Enum.reduce(lista_jugador, 0, fn j, acc -> acc + j.gano end)

          balance = total_ganado - total_gasto

          IO.puts("----------------------")
          IO.puts("Nombre: #{nombre}")
          IO.puts("Total gastado: $#{total_gasto}")
          IO.puts("Total ganado: $#{total_ganado}")
          IO.puts("Balance: $#{balance}")
        end)

      _ ->
        Util.mostrar_error("Error al leer datos")
    end
  end
end
