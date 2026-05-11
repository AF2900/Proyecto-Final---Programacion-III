Mix.install([:jason])

Code.require_file("util.ex", __DIR__)
Code.require_file("modelos/sorteo.ex", __DIR__)
Code.require_file("modelos/cliente.ex", __DIR__)
Code.require_file("modelos/apuesta.ex", __DIR__)
Code.require_file("servidor/servidor_sorteo.ex", __DIR__)
Code.require_file("servidor/servidor_central.ex", __DIR__)

# ─────────────────────────────────────────────────────────────
# nodo_servidor.exs
# Nodo servidor central — debe arrancar PRIMERO
#
# CÓMO EJECUTAR (desde la carpeta Proyecto_Final):
#   elixir --name servidor@127.0.0.1 --cookie loteria_cookie nodo_servidor.exs
# ─────────────────────────────────────────────────────────────

IO.puts("""
==============================================
   SISTEMA LOTERÍA — NODO SERVIDOR CENTRAL
==============================================
Nodo: #{Node.self()}
""")

# Asegura que exista la carpeta de datos
File.mkdir_p("datos")

# Arranca el GenServer y lo registra globalmente (:global)
# para que nodo_admin y nodo_jugador lo encuentren por nombre
{:ok, _pid} = ServidorCentral.iniciar()

IO.puts("[Servidor] ServidorCentral registrado como :servidor_central")
IO.puts("[Servidor] Esperando conexiones de clientes...")
IO.puts("[Servidor] Presiona Ctrl+C para detener.\n")

# Mantiene el nodo vivo indefinidamente
Process.sleep(:infinity)
