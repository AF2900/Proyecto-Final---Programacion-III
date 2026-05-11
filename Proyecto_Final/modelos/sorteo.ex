defmodule Sorteo do
  def crear(nombre, fecha, valor, cantidad_billetes, cantidad_fracciones) do
    %{
      nombre: nombre,
      fecha: fecha,
      valor_billete: valor,
      fracciones: cantidad_fracciones,
      valor_fraccion: div(valor, cantidad_fracciones),
      billetes: generar_billetes(cantidad_billetes, cantidad_fracciones),
      premios: [],
      jugado: false,
      apuestas: [],
      ganador: nil,
      premio_ganado: nil,
      ingresos: 0,
      balance: 0
    }
  end

  defp generar_billetes(cantidad, fracciones) do
    Enum.map(1..cantidad, fn n ->
      %{
        numero: n,
        vendido: false,
        # Cada fracción tiene su propio estado: libre o vendida
        fracciones: generar_fracciones(fracciones)
      }
    end)
  end

  defp generar_fracciones(cantidad) do
    Enum.map(1..cantidad, fn f ->
      %{numero_fraccion: f, vendida: false}
    end)
  end
end
