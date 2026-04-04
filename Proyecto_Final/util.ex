defmodule Util do
  @moduledoc """
  - Autor: Adrián Fernando Pérez
  - Fecha: Marzo 2026
  - Licencia: None
  """

  def mostrar_mensaje(mensaje) do
    mensaje
    |> IO.puts()
  end

  def ingresar(mensaje, :texto) do
    mensaje
    |> IO.gets()
    |> String.trim()
  end

  def ingresar(mensaje, :entero), do: ingresar(mensaje, &String.to_integer/1, :entero)
  def ingresar(mensaje, :real), do: ingresar(mensaje, &String.to_float/1, :real)

  defp ingresar(mensaje, parser, tipo_dato) do
    try do
      mensaje
      |> ingresar(:texto)
      |> parser.()
    rescue
      ArgumentError ->
        "Error, se espera que ingrese un número #{tipo_dato}\n"
        |> mostrar_error()

        mensaje
        |> ingresar(parser, tipo_dato)
    end
  end

  def ingresar_si_no(mensaje) do
    respuesta =
      mensaje
      |> ingresar(:texto)
      |> String.trim()
      |> String.downcase()

    case respuesta do
      "si" -> "si"
      "no" -> "no"
      _ ->
        mostrar_error("Error: debe escribir 'si' o 'no'")
        ingresar_si_no(mensaje)
    end
  end

  def mostrar_error(mensaje) do
    IO.puts(:standard_error, mensaje)
  end
end
