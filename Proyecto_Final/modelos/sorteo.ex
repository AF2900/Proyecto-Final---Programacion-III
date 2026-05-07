defmodule Sorteo do
  def crear(nombre, fecha, valor, billetes) do
    %{
      nombre: nombre,
      fecha: fecha,
      valor_billete: valor,
      billetes: generar_billetes(billetes),
      premios: [],
      jugado: false,
      apuestas: [],
      ganador: nil,
      premio_ganado: nil,
      ingresos: 0,
      balance: 0
    }
  end

  defp generar_billetes(cantidad) do
    Enum.map(1..cantidad, fn n ->
      %{numero: n, vendido: false}
    end)
  end
end
