Mix.install([:jason])

Code.require_file("util.ex", __DIR__)
Code.require_file("modelos/sorteo.ex", __DIR__)
Code.require_file("modelos/cliente.ex", __DIR__)
Code.require_file("servidor/servidor_sorteo.ex", __DIR__)
Code.require_file("servidor/servidor_central.ex", __DIR__)

defmodule Main do
  def main do
    opcion =
      """
      =========================
         SISTEMA LOTERÍA
      =========================
      1. Crear sorteo
      2. Listar sorteos
      3. Ver detalle de sorteo
      4. Comprar billete
      5. Ver apuestas de sorteo
      6. Realizar Sorteo
      7. Eliminar sorteo
      8. Crear premio
      9. Listar premios
      10. Eliminar premio
      11. Ver historial de sorteo
      12. Ver clientes ordenados
      13. Ver resumen de jugadores
      0. Salir
      =========================
      Ingrese una opción:
      """
      |> Util.ingresar(:entero)

    ejecutar_opcion(opcion)
  end

  def ejecutar_opcion(1) do
    ServidorCentral.crear_sorteo()
    main()
  end

  def ejecutar_opcion(2) do
    ServidorCentral.listar_sorteos()
    main()
  end

  def ejecutar_opcion(3) do
    ServidorCentral.ver_detalle_sorteo()
    main()
  end

  def ejecutar_opcion(4) do
    ServidorCentral.comprar_billete()
    main()
  end

  def ejecutar_opcion(5) do
    ServidorCentral.ver_apuestas()
    main()
  end

  def ejecutar_opcion(6) do
    ServidorCentral.realizar_sorteo()
    main()
  end

  def ejecutar_opcion(7) do
    ServidorCentral.eliminar_sorteo()
    main()
  end

  def ejecutar_opcion(8) do
    ServidorCentral.crear_premio()
    main()
  end

  def ejecutar_opcion(9) do
    ServidorCentral.listar_premios()
    main()
  end

  def ejecutar_opcion(10) do
    ServidorCentral.eliminar_premio()
    main()
  end

  def ejecutar_opcion(11) do
    ServidorCentral.historial_sorteo()
    main()
  end

  def ejecutar_opcion(12) do
    ServidorCentral.clientes_ordenados()
    main()
  end

  def ejecutar_opcion(13) do
    ServidorCentral.resumen_jugadores()
    main()
  end

  def ejecutar_opcion(0) do
    Util.mostrar_mensaje("Saliendo del sistema...")
    :ok
  end

  def ejecutar_opcion(_) do
    "Opción inválida"
    |> Util.mostrar_error()

    main()
  end
end

Main.main()
