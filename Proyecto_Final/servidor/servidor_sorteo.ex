defmodule ServidorSorteo do
  def iniciar(sorteo) do
    loop(sorteo)
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

      _ ->
        loop(sorteo)
    end
  end

  defp vender_billete(sorteo, cliente, numero) do
    billetes = sorteo.billetes

    case Enum.find(billetes, fn b -> b.numero == numero end) do
      nil ->
        {sorteo, {:error, "Número inválido"}}

      %{vendido: true} ->
        {sorteo, {:error, "Billete ya vendido"}}

      billete ->
        nuevo_billete = %{billete | vendido: true}

        nuevos_billetes =
          Enum.map(billetes, fn b ->
            if b.numero == numero, do: nuevo_billete, else: b
          end)

        nueva_apuesta = %{
          cliente: %{
            nombre: cliente.nombre,
            edad: cliente.edad
          },
          numero: numero
        }

        nuevas_apuestas = Map.get(sorteo, :apuestas, []) ++ [nueva_apuesta]

        nuevo_sorteo = %{
          sorteo
          | billetes: nuevos_billetes,
            apuestas: nuevas_apuestas
        }

        {nuevo_sorteo, {:ok, cliente.nombre <> " compró el billete #{numero}"}}
    end
  end
end
