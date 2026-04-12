defmodule ServidorSorteo do
  def iniciar(sorteo) do
    loop(sorteo)
  end

  defp loop(sorteo) do
    receive do
      {:obtener_info, pid_cliente} ->
        send(pid_cliente, {:respuesta, sorteo})
        loop(sorteo)

      :detener ->
        :ok

      _ ->
        loop(sorteo)
    end
  end
end
