# Mix.install([:jason])

# Code.require_file("util.ex", __DIR__)
# Code.require_file("modelos/sorteo.ex", __DIR__)
# Code.require_file("modelos/cliente.ex", __DIR__)
# Code.require_file("servidor/servidor_sorteo.ex", __DIR__)
# Code.require_file("servidor/servidor_central.ex", __DIR__)

# defmodule Main do
#   def main do
#     opcion =
#       """
#       =========================
#          SISTEMA LOTERÍA
#       =========================
#       1. Crear sorteo
#       2. Listar sorteos
#       3. Ver detalle de sorteo
#       4. Comprar billete
#       5. Ver apuestas de sorteo
#       6. Realizar Sorteo
#       7. Eliminar sorteo
#       0. Salir
#       =========================
#       Ingrese una opción:
#       """
#       |> Util.ingresar(:entero)

#     ejecutar_opcion(opcion)
#   end

#   def ejecutar_opcion(1) do
#     ServidorCentral.crear_sorteo()
#     main()
#   end

#   def ejecutar_opcion(2) do
#     ServidorCentral.listar_sorteos()
#     main()
#   end

#   def ejecutar_opcion(3) do
#     ServidorCentral.ver_detalle_sorteo()
#     main()
#   end

#   def ejecutar_opcion(4) do
#     ServidorCentral.comprar_billete()
#     main()
#   end

#   def ejecutar_opcion(5) do
#     ServidorCentral.ver_apuestas()
#     main()
#   end

#   def ejecutar_opcion(6) do
#     ServidorCentral.realizar_sorteo()
#     main()
#   end

#   def ejecutar_opcion(7) do
#     ServidorCentral.eliminar_sorteo()
#     main()
#   end

#   def ejecutar_opcion(0) do
#     "Saliendo del sistema..."
#     |> Util.mostrar_mensaje()
#   end

#   def ejecutar_opcion(_) do
#     "Opción inválida"
#     |> Util.mostrar_error()

#     main()
#   end
# end

# Main.main()
