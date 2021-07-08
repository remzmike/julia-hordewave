# Hordewave Julia : a minimal port from my javascript version
#
# 20210705: installed julia for the first time
# 20210708: v01 slanged
#
#=

* Move with WASD/ARROWS

* Shoot with mouse

* How I run it, as an ultimate julia newb:

    julia> cd("GameOne")

    (@v1.6) pkg> activate .

    julia> using GameOne

    julia> rungame("C:\\code21-julia-gamezero\\hordewave\\Main.jl")

=#

using GameOne # Modified GameZero to have on_key_up. Standard version only has on_key_down. May go back someday.
using Colors

module Hordewave
    include("Hordewave.jl")
end

WIDTH = 640
HEIGHT = 480
BACKGROUND=colorant"black"

lastFrameTime = Base.time_ns()

function draw(g::Game)
    clear()

    dt = (Base.time_ns() - lastFrameTime) / 1000000
    global lastFrameTime
    lastFrameTime = Base.time_ns()

    #println("dt ", dt)
    Hordewave.set_ui_state_dt(dt) # nano to milli
    Hordewave.do_hordewave(g, 0, 0)
end

function update(g::Game)
    # doing everything in draw for now
end

function on_mouse_move(g::Game, pos)
    x, y = pos
    Hordewave.set_ui_state_mouselocation_x(x)
    Hordewave.set_ui_state_mouselocation_y(y)
end

function on_key_down(game, key)
    Hordewave.on_key_down(key)
end

function on_key_up(game, key)
    Hordewave.on_key_up(key)
end

function on_mouse_down(game, pos, button)
    Hordewave.on_mouse_down(pos, button)
end

function on_mouse_up(game, pos, button)
    Hordewave.on_mouse_up(pos, button)
end