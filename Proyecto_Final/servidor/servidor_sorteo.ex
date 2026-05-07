defmodule ServidorSorteo do
  def iniciar(sorteo) do
    spawn(fn -> loop(sorteo) end)
  end

  defp loop(sorteo) do
    receive do
      {:comprar, cliente, numero, pid_cliente, pid_central} ->
        {nuevo_sorteo, respuesta} = vender_billete(sorteo, cliente, numero)
        send(pid_cliente, respuesta)
        send(pid_central, {:actualizar_sorteo, nuevo_sorteo})
        loop(nuevo_sorteo)

      {:obtener_info, pid_cliente} ->
        send(pid_cliente, {:respuesta, sorteo})
        loop(sorteo)

      {:obtener_apuestas, pid_cliente} ->
        send(pid_cliente, {:apuestas, Map.get(sorteo, :apuestas, [])})
        loop(sorteo)

      {:realizar_sorteo, pid_cliente, pid_central} ->
        {nuevo_sorteo, resultado} = realizar_sorteo(sorteo)
        send(pid_cliente, resultado)
        send(pid_central, {:actualizar_sorteo, nuevo_sorteo})
        loop(nuevo_sorteo)

      {:agregar_premio, premio, pid_central} ->
        nuevo_sorteo = %{
          sorteo
          | premios: sorteo.premios ++ [premio]
        }

        send(pid_central, {:actualizar_sorteo, nuevo_sorteo})
        send(pid_central, {:premio_agregado, "Premio agregado correctamente"})
        loop(nuevo_sorteo)

      {:eliminar_premio, indice, pid_central} ->
        cond do
          length(sorteo.premios) == 0 ->
            send(pid_central, {:error, "No hay premios para eliminar"})
            loop(sorteo)

          indice < 0 or indice >= length(sorteo.premios) ->
            send(pid_central, {:error, "Índice inválido"})
            loop(sorteo)

          true ->
            nuevos_premios =
              List.delete_at(sorteo.premios, indice)

            nuevo_sorteo = %{
              sorteo
              | premios: nuevos_premios
            }

            send(pid_central, {:actualizar_sorteo, nuevo_sorteo})
            send(pid_central, {:premio_eliminado, "Premio eliminado correctamente"})
            loop(nuevo_sorteo)
        end

      _ ->
        loop(sorteo)
    end
  end

  defp vender_billete(sorteo, cliente, numero) do
    if sorteo.jugado do
      {sorteo, {:error, "El sorteo ya fue realizado"}}
    else
      case Enum.find(sorteo.billetes, fn b -> b.numero == numero end) do
        nil ->
          {sorteo, {:error, "Número inválido"}}

        %{vendido: true} ->
          {sorteo, {:error, "Billete ya vendido"}}

        billete ->
          nuevo_billete = %{billete | vendido: true}

          nuevos_billetes =
            Enum.map(sorteo.billetes, fn b ->
              if b.numero == numero, do: nuevo_billete, else: b
            end)

          cliente_map = %{
            nombre: cliente.nombre,
            edad: cliente.edad,
            documento: cliente.documento,
            tarjeta: cliente.tarjeta
          }

          nueva_apuesta = %{
            cliente: cliente_map,
            numero: numero
          }

          nuevas_apuestas = sorteo.apuestas ++ [nueva_apuesta]

          nuevo_sorteo = %{
            sorteo
            | billetes: nuevos_billetes,
              apuestas: nuevas_apuestas,
              ingresos: sorteo.ingresos + sorteo.valor_billete
          }

          {nuevo_sorteo, {:ok, cliente.nombre <> " compró el billete #{numero}"}}
      end
    end
  end

  defp realizar_sorteo(sorteo) do
    if sorteo.jugado do
      {sorteo, {:error, "El sorteo ya fue realizado"}}
    else
      vendidos = Enum.filter(sorteo.billetes, fn b -> b.vendido end)

      if vendidos == [] do
        {sorteo, {:error, "No hay billetes vendidos"}}
      else
        ganador = Enum.random(vendidos)

        premio =
          if sorteo.premios == [] do
            valor_base = div(sorteo.ingresos, 3)
            %{nombre: "Premio base", valor: valor_base}
          else
            Enum.random(sorteo.premios)
          end

        apuesta_ganadora =
          Enum.find(sorteo.apuestas, fn a -> a.numero == ganador.numero end)

        balance = sorteo.ingresos - premio.valor

        nuevo_sorteo = %{
          sorteo
          | jugado: true,
            ganador: ganador.numero,
            premio_ganado: premio,
            balance: balance
        }

        mensaje =
          if apuesta_ganadora do
            "Número ganador: #{ganador.numero} - Ganador: #{apuesta_ganadora.cliente.nombre} - Premio: #{premio.nombre} ($#{premio.valor})"
          else
            "Número ganador: #{ganador.numero} - Premio: #{premio.nombre} ($#{premio.valor})"
          end

        {nuevo_sorteo, {:ok, mensaje}}
      end
    end
  end
end
