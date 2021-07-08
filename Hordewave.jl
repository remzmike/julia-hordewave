module HordewaveGen
    include("HordewaveGen.jl")
end

using GameOne
Rect = GameOne.Rect
Line = GameOne.Line
using Colors

mutable struct TPointF
    x :: Float64
    y :: Float64
end

mutable struct TPointI
    x :: Int64
    y :: Int64
end

# ["down", e.key]
struct TButtonEvent
    kind :: String
    key :: String
end

mutable struct TGame
    gz :: Union{GameOne.Game, Nothing}
    dt :: Float64 #dt: 0,  # nolive: i think i can get this from gz, but idc now
    # 'buttons' are both keys and mouse buttons
    button_events :: Vector{TButtonEvent} # [], # resets before interval
    buttons_down :: Dict{String, Bool} # {},
    #buttons_went_down :: Vector{String} # [], # resets before frame, using list because it should be very small
    #buttons_went_up :: Vector{String} # [], # ^ (also, for GameOne this is *ONLY* mouse ups)
    mouse_world_xy :: TPointF # null,
    game_x :: Int64 #null,
    game_y :: Int64 #null,
    mouse_on_game :: Bool # null,
    paused :: Bool #false,
    bypass_pause_count :: Int64 # 0, # bypass pause for this many frames
    #toasts: []
end

mutable struct TFrame
    count_enemies_updated::Int64 # 0,
    count_enemies_not_updated::Int64 # 0,
    count_bullets_active::Int64 # 0,
    count_bullets_not_active::Int64 # 0,
end

mutable struct TCamera
    view_width :: Int64
    view_height :: Int64
    view_width_in_cells :: Int64
    view_height_in_cells :: Int64
    position :: TPointI
end

struct TColor
    r :: UInt8
    g :: UInt8
    b :: UInt8
    a :: Float64
end

mutable struct TCell{T}
    # bruh: https://discourse.julialang.org/t/how-to-deal-with-recursive-type-dependencies-in-immutable-structs/53173/2
    entity :: Union{T, Nothing} # can't define this as TEntity
    passives :: Vector{T} # same problem :: Array{TEntity,1} # passive entities
    floor :: String
    xy :: TPointI
    i :: Int64
end

mutable struct TEntity
    i :: Int64
    active :: Bool
    position :: TPointF
    size :: Int64
    speed :: Float64
    kind :: String
    sub_kind :: String
    cell :: Union{TCell{TEntity}, Nothing}
    direction :: Union{Int64, Nothing}
    debug_color :: Union{TColor, Nothing}
    anim_kind :: String
    anim_frame :: Int64
    anim_cooldown :: Float64
    hit_anim :: Bool
    is_moving :: Bool
    health :: Int64
    health_max :: Int64
    angle :: Float64
    attack_state :: String
    attack_windup :: Float64
    attack_windup_default :: Float64
    attack_cooldown :: Float64
    attack_cooldown_default :: Float64
    attack_damage :: Int64
    tint_cooldown :: Float64
    pending_death :: Bool
end

# console.assert(xy[0] + xy[1] * Map.width_in_cells == i)
TCell(xy, i) = TCell{TEntity}(
    nothing, # entity
    Vector{TEntity}(),# passives
    "", # floor
    xy, # xy
    i, # i
)

function randomInt(a, b)
    delta = b - a
    r = floor(rand() * delta)
    return Int64(a + r)
end

TEntity(kind, i) = TEntity(
    i, # i
    true, # active
    TPointF(0, 0), # position
    Map.cell_size, #size :: Int64 # Map.cell_size,
    1, #speed :: Float64
    kind, #kind :: String
    "",  #sub_kind :: String
    nothing, #cell :: TCell{TEntity}
    nothing, #direction :: Int64 # randomInt(0, 7),
    TColor(0,0,0,0), #debug_color :: TColor # null,
    "", #anim_kind :: String #null,
    0, #anim_frame :: Int64 # null,
    0.0, #anim_cooldown :: Float64 # null,
    false, #hit_anim :: Bool # false,
    false, #is_moving :: Bool # false,
    1, #health :: Int64 # 1
    1, #health_max :: Int64 # 1,
    0.0, #angle :: Float64 # 0,
    "idle", #attack_state :: String # 'idle', // idle, windup, attack
    30.0, #attack_windup :: Float64 # 30,
    30.0, #attack_windup_default :: Float64 # 30,
    120.0, #attack_cooldown :: Float64 # 120,
    120.0, #attack_cooldown_default :: Float64 # 120,
    1, #attack_damage :: Int64 # 1,
    0.0, #tint_cooldown :: Float64
    false, #pending_death
)

TEntity(kind) = TEntity(kind, 0)

mutable struct TMap
    width :: Int64
    height :: Int64
    cell_size :: Int64
    cell_grid :: Vector{TCell{TEntity}}
    width_in_cells :: Int64
    height_in_cells :: Int64
end

mutable struct TBullet
    active :: Bool # false,
    start_xy :: TPointF # [0.0, 0.0],
    position :: TPointF # [0.0, 0.0],
    position_prev :: TPointF # [0.0, 0.0],
    direction :: TPointF # [0.0, 0.0],
    speed :: Float64 # 0.0,
    i :: Union{Int64, Nothing} # null,
    pending_deactivation :: Bool # false,
    collisions :: Vector{TEntity} # // resets before interval
    previous_collision_ids :: Vector{Int64} # [], // does not reset
    health :: Int64 # 0 | 0,
    health_max :: Int64 # 0 | 0,
    damage :: Int64 # 0 | 0,
    angle :: Float64 # 0.0
end

TBullet() = TBullet(
    false, # active: false,
    TPointF(0.0, 0.0), # start_xy: [0.0, 0.0],
    TPointF(0.0, 0.0), # position [0.0, 0.0],
    TPointF(0.0, 0.0), # position_prev: [0.0, 0.0],
    TPointF(0.0, 0.0), # direction: [0.0, 0.0],
    0.0, # speed: 0.0,
    nothing, # i: null,
    false, # pending_deactivation: false,
    Vector{TEntity}(), # collisions: [], // resets before interval
    Vector{Int64}(), # previous_collision_ids: [], // does not reset
    0, # health: 0 | 0,
    0, # health_max: 0 | 0,
    0, # damage: 0 | 0,
    0.0 # angle: 0.0
)

Config = Dict(
    "player.speed" => 3, # 2
    "player.attack_cooldown" => 4, # 20,
    "player.weapon.bullet_speed" => 8, # 6
    "player.weapon.bullet_health" => 2, # 3
    "player.weapon.bullet_damage" => 3,
    "player.light_size" => 100, # 100
    "engine.bullet_pool_initial_size" => 200,
    "flags.clip_game_window" => true,
    "flags.draw" => true,
    "flags.draw_bullet_debug" => true,
    "flags.draw_bullet_debug2" => true,
    "flags.draw_entities_debug" => true,
    "flags.draw_player_debug_line" => false,
    "flags.draw_player_debug_walk" => false,
    "flags.update_enemies" => false, # will be set true on first attack
    "flags.update_bullets" => true,
    "flags.update_distant_enemies" => false,
    "flags.deactivate_distant_bullets" => true,
    "flags.add_entity_death" => true,
    "flags.draw_passive_entities" => true,
    "flags.draw_sprite_tint" => true,
)
if (true)
    Config["player.speed"] = 4
    Config["player.attack_cooldown"] = 1
    Config["player.weapon.bullet_health"] = 1
    Config["player.weapon.bullet_speed"] = 12
    if (false) # sicko mode
        Config["player.speed"] = 6
        Config["player.attack_cooldown"] = 0
        Config["player.weapon.bullet_damage"] = 20
        Config["player.weapon.bullet_health"] = 20
    end
end

Map = TMap(3200, 3200, 32, Vector{TCell{TEntity}}(undef, 100*100), 100, 100)
#Camera = TCamera(WIDTH, HEIGHT, 40, 30, TPointI(0, 0)) # WIDTH/HEIGHT duplicated
Camera = TCamera(640, 480, 40, 30, TPointI(0, 0))
Frame = TFrame(0, 0, 0, 0)

Entities = Vector{Union{TEntity, Nothing}}(nothing, 1000)
Bullets = Vector{Union{TBullet, Nothing}}(nothing, Config["engine.bullet_pool_initial_size"])
#ParticleSystems = Array{TParticleSystems}(undef, 0)

Game = TGame(
    nothing, # gz::Game
    0, #dt::Float64 #dt: 0,
    # 'buttons' are both keys and mouse buttons
    Vector{TButtonEvent}(), #button_events :: Array{TButtonEvent,1} # [], # resets before interval
    Dict{String, Bool}(), #buttons_down
    #Vector{String}(), #buttons_went_down :: Array{String,1} # [], # resets before frame, using list because it should be very small
    #Vector{String}(), #buttons_went_up
    TPointF(0, 0), #mouse_world_xy :: TPointF # null,
    0, #game_x :: Int64 #null,
    0, #game_y :: Int64 #null,
    false, #mouse_on_game :: Bool # null,
    false, #paused :: Bool #false,
    0, #bypass_pause_count :: Int64 # 0, # bypass pause for this many frames
    #canvas: null, # main drawing canvas, added for pause support
    #context: null, # main drawing canvas context,
    #entity_canvas: null, # a canvas for doing complex entity draws with blendmodes
    #entity_context: null,
    #toasts: []
)

const Direction = (
    Up = 1,
    UpRight = 2,
    Right = 3,
    DownRight = 4,
    Down = 5,
    DownLeft = 6,
    Left = 7,
    UpLeft = 8
)

const DirectionByBitfield = [
    nothing, # 0000
    Direction.Left, # 0001
    Direction.Right, # 0010
    nothing, # 0011
    Direction.Up, # 0100
    Direction.UpLeft, # 0101
    Direction.UpRight, # 0110
    nothing, # 0111
    Direction.Down, # 1000
    Direction.DownLeft, # 1001
    Direction.DownRight, # 1010
    nothing,
    nothing,
    nothing,
    nothing,
    nothing,
]

const DirectionOffset = [
    TPointF(0, -1), # Up
    TPointF(1, -1), # UpRight
    TPointF(1, 0), # Right
    TPointF(1, 1), # DownRight
    TPointF(0, 1), # Down
    TPointF(-1, 1), # DownLeft
    TPointF(-1, 0), # Left
    TPointF(-1, -1), # UpLeft
]

const Directions180 = [
    [Direction.Up, Direction.UpLeft, Direction.UpRight, Direction.Left, Direction.Right],
    [Direction.UpRight, Direction.Right, Direction.Up, Direction.UpLeft, Direction.DownRight],
    [Direction.Right, Direction.UpRight, Direction.DownRight, Direction.Up, Direction.Down],
    [Direction.DownRight, Direction.Right, Direction.Down, Direction.DownLeft, Direction.UpRight],
    [Direction.Down, Direction.DownLeft, Direction.DownRight, Direction.Left, Direction.Right],
    [Direction.DownLeft, Direction.Left, Direction.Down, Direction.UpLeft, Direction.DownRight],
    [Direction.Left, Direction.UpLeft, Direction.DownLeft, Direction.Up, Direction.Down],
    [Direction.UpLeft, Direction.Left, Direction.Up, Direction.UpRight, Direction.DownLeft],
]

function init()

    #hordewave_tiles_init()

    @assert length(Map.cell_grid) == Map.width_in_cells * Map.height_in_cells
    for y in 0:Map.height_in_cells-1
        for x in 0:Map.width_in_cells-1
            cell = TCell(TPointI(x, y), length(Map.cell_grid))
            # we don't push here because the array is already sized
            #push!(Map.cell_grid, cell)
            i = x + y * Map.width_in_cells
            Map.cell_grid[i+1] = cell
        end
    end
    @assert length(Map.cell_grid) == Map.width_in_cells * Map.height_in_cells

    for i in 1:Config["engine.bullet_pool_initial_size"]
        o = TBullet()
        o.i = i
        Bullets[i] = o
    end

    HordewaveGen.generate()
    #hordewave_gen.generate2()

    player_world_xy = TPointF(
        Map.width / 2 + Map.cell_size / 2,
        Map.height / 2 + Map.cell_size / 2
    )

    player_cell_xy = world_to_cell_xy(player_world_xy)
    player_cell = get_cell(player_cell_xy)

    if (player_cell.entity != nothing)
        deactivate_entity(player_cell.entity)
    end

    player = TEntity("player")
    player.health = 5
    player.health_max = 5
    player.sub_kind = "elf_m"
    player.speed = Config["player.speed"]
    player.position = TPointF(
        player_world_xy.x,
        player_world_xy.y
    )
    player.attack_cooldown = 0
    player_cell.entity = player
    player.cell = player_cell
    player.anim_kind = "idle"
    player.anim_frame = 0
    player.anim_cooldown = 30

    global Player
    Player = player;

    #add_toast("shoot with mouse");
    #add_toast("move with wasd");
end

function world_to_cell_xy(world_xy::TPointF)
    #@assert world_xy.x >= 0
    #@assert world_xy.y >= 0
    #@assert world_xy.x < Map.width
    #@assert world_xy.y < Map.height
    return TPointI(
        trunc(Int64, world_xy.x / Map.cell_size),
        trunc(Int64, world_xy.y / Map.cell_size)
    )
end

function cell_to_world_xy(cell_xy::TPointI)
    return TPointF(
        cell_xy.x * Map.cell_size,
        cell_xy.y * Map.cell_size
    )
end

function world_to_screen_xy(world_xy::TPointF)
    return TPointI(
        trunc(Int64, world_xy.x - Camera.position.x),
        trunc(Int64, world_xy.y - Camera.position.y)
    )
end

function screen_to_world_xy(screen_xy::TPointI)
    dx = screen_xy.x - Game.game_x
    dy = screen_xy.y - Game.game_y
    return TPointF(
        Camera.position.x + dx,
        Camera.position.y + dy
    )
end

function get_cell(cell_xy, arg2)
    # console.assert(arg2 == null);
    cell_x = cell_xy.x
    cell_y = cell_xy.y
    return get_cell2(cell_x, cell_y)
end

function get_cell(cell_xy)
    return get_cell(cell_xy, nothing)
end

function get_cell2(cell_x, cell_y)
    # console.assert(cell_y != null);
    if (cell_x >= 0 && cell_y >= 0 && cell_x < Map.width_in_cells && cell_y < Map.height_in_cells)
        #println(length(Map.cell_grid))
        @assert length(Map.cell_grid) == Map.width_in_cells * Map.height_in_cells
        i = cell_x + cell_y * Map.width_in_cells + 1
        return Map.cell_grid[i]
    else
        return nothing
    end
end

function deactivate_entity(entity)
    entity.active = false
    entity.cell.entity = nothing
    entity.cell = nothing
end

#function deactivate_passive_entity(entity)
#    entity.active = false
#    const index = entity.cell.passives.indexOf(entity)
#    if (index >= 0)
#        entity.cell.passives.splice(index, 1)
#    end
#end

function calc_new_position(entity, direction_vector)
    @assert direction_vector != nothing
    entity_speed = (entity.speed / 16) * Game.dt
    new_position = TPointF(
        entity.position.x + direction_vector.x * entity_speed,
        entity.position.y + direction_vector.y * entity_speed
    )
    return new_position
end

function get_cell_for_position(position)
    #println(position)
    cell_xy = world_to_cell_xy(position)
    #println(cell_xy)
    return get_cell(cell_xy)
end

function is_same_cell(a, b)
    @assert ( a.xy.x === b.xy.x && a.xy.y == b.xy.y ) == ( a == b )
    #//return a === b;
    return a.xy.x === b.xy.x && a.xy.y == b.xy.y
end

#// can entity move to this cell?
function is_cell_movement_valid(entity, new_cell)
    allow_diagonal_cheese = true #// allow passing through diagonal corners
    if (entity.kind == "player")
        allow_diagonal_cheese = false
    end
    if (allow_diagonal_cheese)
        #// the most basic form is like this
        #// only check one cell, enemies can pass through diagonal corners
        return new_cell != nothing && new_cell.entity == nothing
    else
        #// check sides, but only when direction between entity cell and new_cell is diagonal
        cell_dx = new_cell.xy.x - entity.cell.xy.x
        cell_dy = new_cell.xy.y - entity.cell.xy.y
        @assert abs(cell_dx) <= 1;
        @assert abs(cell_dy) <= 1;
        #{ // shouldn't be checking valid for same cell
            @assert entity.cell != new_cell
            @assert ( abs(cell_dx) + abs(cell_dy) ) != 0
        #}
        is_straight = ( abs(cell_dx) + abs(cell_dy) ) == 1

        if (is_straight)
            #// new cell needs to be open
            return new_cell != nothing && new_cell.entity == nothing
        else
            #// new cell -AND- at least one side needs to be open
            #// this prevents diagonal movement across corners
            side_a = get_cell2(new_cell.xy.x - cell_dx, new_cell.xy.y)
            side_b = get_cell2(new_cell.xy.x, new_cell.xy.y - cell_dy)

            side_a_good = false
            side_b_good = false
            diagonal_pass_through_enemies = false
            if (diagonal_pass_through_enemies)
                #// the 'enemy' checks mean enemies can be diagonally passed through... though im not sure how useful that is
                side_a_good = side_a != nothing && (side_a.entity == nothing || (side_a.entity.kind == "enemy"))
                side_b_good = side_b != nothing && (side_b.entity == nothing || (side_b.entity.kind == "enemy"))
            else
                side_a_good = side_a != nothing && side_a.entity == nothing
                side_b_good = side_b != nothing && side_b.entity == nothing
            end
            new_cell_good = new_cell != nothing && new_cell.entity == nothing
            return new_cell_good && (side_a_good || side_b_good)
        end
    end
end

function set_entity_position(entity, new_position)
    @assert entity != nothing
    @assert new_position != nothing
    @assert new_position.x != nothing
    @assert new_position.y != nothing
    //
    new_cell = get_cell_for_position(new_position);
    @assert new_cell != nothing
    #@assert new_cell.entity == nothing || new_cell.entity == entity
    if (new_cell.entity == nothing)
    else
        if new_cell.entity != entity
            println("AAA ", new_cell.entity)
            println("BBB ", entity)
        end
        @assert new_cell.entity == entity
    end


    old_cell = entity.cell
    @assert old_cell != nothing

    entity.position.x = new_position.x
    entity.position.y = new_position.y

    entity.cell = new_cell
    old_cell.entity = nothing
    new_cell.entity = entity
end

function find_empty_slot(array)
    j = nothing
    #println(length(array))
    for i in 1:length(array)
        el = array[i]
        if (el == nothing || el.active == false)
            j = i
            break
        end
    end
    return j
end

function add_entity(o)
    @assert o.position.x >= 0 || o.position.x < 0
    @assert o.position.y >= 0 || o.position.y < 0
    j = find_empty_slot(Entities)

    if (j == nothing)
        # no slot, add one
        o.i = length(Entities) + 1;
        push!(Entities, o);
    else
        o.i = j;
        Entities[j] = o;
    end

    @assert o.position.x >= 0 || o.position.x < 0
    @assert o.position.y >= 0 || o.position.y < 0

    push!(Entities, o)
end

################################################################################

#// return [false, false] when no movement
#// return [true, false] when moved to same cell
#// return [true, true] when moved to new cell
function try_move_entity(entity, direction_offset)
    if (!entity.active)
        return
    end

    direction_vector = vNorm(direction_offset)
    @assert direction_vector != nothing
    new_position = calc_new_position(entity, direction_vector)
    @assert new_position != nothing
    new_position_cell = get_cell_for_position(new_position);

    if (new_position_cell == nothing)
        return [false, false] #// no cell at new position, probably map edge, just continue
    else
        cell_dx = new_position_cell.xy.x - entity.cell.xy.x
        cell_dy = new_position_cell.xy.y - entity.cell.xy.y

        @assert abs(cell_dx) < 2 #// new cell must be adjacent! lower speed or do multiple steps to work around this
        @assert abs(cell_dy) < 2

        same_cell = is_same_cell(entity.cell, new_position_cell)

        if (same_cell)
            set_entity_position(entity, new_position)
            return [true, false]
        else
            #// basic working idea is:
            #//const cell_movement_valid = new_position_cell && new_position_cell.entity == null;

            #// const adjacent_cell = get_cell_adjacent(entity.cell, direction);
            #//
            #// movement here is not necessarily to the cell that sits <direction> of origin
            #// because a unit may be moving southwest from the southeastern corner of a cell
            #// which means they are going to be in the southern adjacent cell not the southwestern adjacent cell
            #// actually, will have to do like a line algorithm between entity current pos and new pos
            #// but for now i will assume new pos is in an adjacent cell

            cell_movement_valid = is_cell_movement_valid(entity, new_position_cell)
            if (cell_movement_valid)
                entity.debug_color = nothing
                #//const new_cell = get_cell_adjacent(entity.cell, direction)
                #/console.assert(new_cell != null)
                set_entity_position(entity, new_position)
                return [true, true]
            end
            #=/* else {
                entity.direction = null;
                entity.debug_color = 'rgba(255,255,255,1)';
            }*/=#
        end

    end

    return  [false, false]
end

function get_top_left_world_xy()
    min_x = 0
    min_y = 0
    max_x = Map.width - Camera.view_width
    max_y = Map.height - Camera.view_height

    x = Player.position.x - Camera.view_width/2
    x = max(min_x, x)
    x = min(max_x, x)

    y = Player.position.y - Camera.view_height/2
    y = max(min_y, y)
    y = min(max_y, y)

    x = floor(x)
    y = floor(y)

    return TPointF(x, y)
end

function is_button_down(name)
    match = get(Game.buttons_down, name, false)
    return match
end

# not gonna do this until i know how key events work, ONLY the 'p' pause key uses it in js version
#function is_button_went_down(button)
#    matches = findall(el -> el == button, Game.buttons_went_down)
#    return length(matches) > 0
#end

function is_mouse_on_game()
    game_x0_screen = Game.game_x
    game_x1_screen = Game.game_x + Camera.view_width
    game_y0_screen = Game.game_y
    game_y1_screen = Game.game_y + Camera.view_height
    if (
        ui_state_mouselocation_x >= game_x0_screen && ui_state_mouselocation_x < game_x1_screen &&
        ui_state_mouselocation_y >= game_y0_screen && ui_state_mouselocation_y < game_y1_screen
    )
        return true
    end
    return false
end

# ui state hacks
ui_state_mouselocation_x = 0
function set_ui_state_mouselocation_x(x)
    global ui_state_mouselocation_x
    ui_state_mouselocation_x = x
end

ui_state_mouselocation_y = 0
function set_ui_state_mouselocation_y(y)
    global ui_state_mouselocation_y
    ui_state_mouselocation_y = y
end

ui_state_dt = 0
function set_ui_state_dt(dt)
    global ui_state_dt
    ui_state_dt = dt
end

function do_hordewave(gz::GameOne.Game, game_x, game_y)

    Game.gz = gz # the GameOne game object

    Frame.count_enemies_updated = 0
    Frame.count_enemies_not_updated = 0
    Frame.count_bullets_active = 0
    Frame.count_bullets_not_active = 0

    allow_game_step = Game.paused == false || Game.bypass_pause_count > 0

    if (allow_game_step)

        Game.dt = ui_state_dt
        #println("Game.dt ", Game.dt)
        max_dt = 33
        Game.dt = min(Game.dt, max_dt)

        if (Game.bypass_pause_count > 0)
            #console.log("[ bypassing pause ]", Game.bypass_pause_count)
            Game.bypass_pause_count -= 1
        end

        # input
        Game.game_x = game_x
        Game.game_y = game_y
        if (is_mouse_on_game())
            #ui.state.auto_cursor = false
            #document.body.style.cursor = "crosshair"
            Game.mouse_world_xy = screen_to_world_xy(TPointI(ui_state_mouselocation_x, ui_state_mouselocation_y))
            Game.mouse_on_game = true
        else
            #ui.state.auto_cursor = true
            Game.mouse_world_xy = nothing
            Game.mouse_on_game = false
        end

        process_button_events()
        #handle_pause_buttons()

        #Game.context.fillStyle = "rgba(0,0,0,1)"
        #Game.context.fillRect(0, 0, Game.canvas.width, Game.canvas.height)
        #Game.context.clearRect(0, 0, Game.canvas.width, Game.canvas.height)
        #Game.context.translate(game_x, game_y)

        top_left_world_xy = get_top_left_world_xy()
        Camera.position.x = top_left_world_xy.x
        Camera.position.y = top_left_world_xy.y

        update_player()
        update_entities()
        #update_entities_adjacent()
        update_bullets()
        #update_particle_systems()

        if (Config["flags.draw"])
            #draw_background()
            draw_entities_debug()
            #draw_entities() # player drawn here
            #draw_particle_systems()
            draw_bullets()
            #draw_player_debug()
            #draw_foreground()
            #draw_hud()
        end
        cleanup_bullets()
        #cleanup_particle_systems()

        #Game.context.translate(-game_x, -game_y)

    else
        # game is paused...
        process_button_events()
        #handle_pause_buttons()
    end

    #if (Config["flags.clip_game_window"])
    #    uidraw.begin_clip(RectangleP(Game.game_x, Game.game_y, Camera.view_width, Camera.view_height))
    #end

    # blit canvas... this is the only ui.context call
    #ui.context.drawImage(Game.canvas, 0, 0) // todo: change this so we're drawing at Game.game_x/y (get rid of concept of drawing whole screen... i guess...)

    #if (!allow_game_step) {
    #    const text = "------  [ paused ]  ------"
    #    uidraw.text_centered(
    #        text,
    #        RectangleP(Game.game_x, Game.game_y + Camera.view_height - 40, Camera.view_width, 40),
    #        [255,255,255,1]
    #    )
    #}

    #do_game_ui()

    if (Config["flags.clip_game_window"])
        #uidraw.end_clip()
    end
end

function update_player()
    entity = Player

    #//// move ////

    command_up = is_button_down("UP") || is_button_down("W")
    command_left = is_button_down("LEFT") || is_button_down("A")
    command_right = is_button_down("RIGHT") || is_button_down("D")
    command_down = is_button_down("DOWN") || is_button_down("S")

    movement_bits = 0

    if (command_left)
        movement_bits |= 1
    end
    if (command_right)
        movement_bits |= 2
    end
    if (command_up)
        movement_bits |= 4
    end
    if (command_down)
        movement_bits |= 8
    end

    #println("movement_bits ", movement_bits)
    direction = DirectionByBitfield[movement_bits + 1]
    #if (direction != nothing) #// stay facing last direction
    #    #entity.direction = direction
    #end

    moved = false
    if (direction == nothing)
        #// pass (dont move moved)
    else
        direction_vector = DirectionOffset[direction]
        move_result = try_move_entity(entity, direction_vector)
        if (move_result[1] && move_result[2] == false)
            #// moved to same cell
            moved = true;
        elseif (move_result[1] && move_result[2])
            #// moved to a new cell
            moved = true;
        else
            #// try x-slide
            direction_vector2 = TPointI(0, direction_vector.y)
            move_result2 = try_move_entity(entity, direction_vector2)
            if (move_result2[1])
                #// moved with x-slide
                moved = true;
            else
                #// try y-slide
                direction_vector3 = TPointI(direction_vector.x, 0)
                move_result3 = try_move_entity(entity, direction_vector3)
                if (move_result3[1])
                    #// moved with y-slide
                    moved = true
                end
            end
        end
    end

    Player.is_moving = moved

    #//// attack ////

    #//Player.attack_cooldown -= 1
    Player.attack_cooldown -= (1 * 16) / Game.dt
    can_attack = Player.attack_cooldown <= 0
    command_attack = is_button_down("MouseLeft")

    # julia hack, pause ents until mouse press
    if (command_attack)
        Config["flags.update_enemies"] = true
    end

    if (can_attack)
        if (is_mouse_on_game() && command_attack)
            start = TPointF(Player.position.x, Player.position.y)
            direction = get_aim_vector()
            speed = Config["player.weapon.bullet_speed"]
            health = Config["player.weapon.bullet_health"]
            damage = Config["player.weapon.bullet_damage"]
            add_bullet(start, direction, speed, health, damage, get_aim_angle())
            Player.attack_cooldown = Config["player.attack_cooldown"]
        end
    end

    # //// anim state ////

    update_entity_animation(Player)

end

function update_entities()

    for i in 1:length(Entities)

        entity = Entities[i]

        if (entity == nothing || !entity.active)
            continue
        end

        if (entity.health <= 0)
            entity.pending_death = true
            #add_entity_death(entity)
            deactivate_entity(entity)
        end

        if (entity.tint_cooldown > 0) #// disable for fun ?
            entity.tint_cooldown -= (1 * 16) / Game.dt
        end

        if (entity.kind == "enemy")
            if (Config["flags.update_distant_enemies"] || is_xy_within_active_range(entity.position))
                Frame.count_enemies_updated += 1
                update_enemy(entity)
            else
                Frame.count_enemies_not_updated += 1
            end
        elseif (entity.kind == "death")
            entity.angle += 0.3
            entity.size -= 0.5
            if (entity.size <= 0)
                deactivate_passive_entity(entity)
            end
        end
    end
end

function update_enemy(entity)
    if (!entity.active) return end
    if (!Config["flags.update_enemies"]) return end

    @assert entity.position != nothing
    @assert entity.position.x != nothing
    @assert entity.position.y != nothing

    #//// movement ////

    direction_to_player = get_direction(entity.position, Player.position)
    @assert direction_to_player != nothing
    directions_180 = Directions180[direction_to_player]

    #// loop directions 180, if can move, then do so and break
    #for (let i = 0; i < directions_180.length; i++)
    for i in 1:length(directions_180)
        direction = directions_180[i]
        direction_offset = DirectionOffset[direction]
        move_result = try_move_entity(entity, direction_offset)
        if (move_result[1])
            entity.direction = direction;
            break
        end
    end

    #//// attack ////

    if (entity.attack_cooldown > 0) entity.attack_cooldown -= (1 * 16) / Game.dt end
    if (entity.attack_windup > 0) entity.attack_windup -= (1 * 16) / Game.dt end

    #//// animation ////

    update_entity_animation(entity)
end

function update_entity_animation(o)
    if (o.anim_kind == "idle" && o.is_moving)
        o.anim_kind = "run"
        o.anim_frame = -1
        o.anim_cooldown = 0
    end

    if (o.anim_kind == "run" && !o.is_moving)
        o.anim_kind = "idle"
        o.anim_frame = -1
        o.anim_cooldown = 0
    end

    if (o.anim_cooldown <= 0)
        o.anim_frame += 1
        mod = 0
        if (o.anim_kind == "idle")
            o.anim_cooldown = 30
            mod = 4
        elseif (o.anim_kind == "run")
            o.anim_cooldown = round(16 / o.speed)
            mod = 4;
        elseif (o.anim_kind == "hit")
            o.anim_kind = "idle" #// todo: store prev and set to prev here? idk
            o.anim_cooldown = 30
            mod = 1
        else
            o.anim_cooldown = 20
        end
        if (mod != nothing)
            o.anim_frame = o.anim_frame % mod
        end
    end

    #//o.anim_cooldown -= 1;
    step_time = (1 * 16) / Game.dt
    o.anim_cooldown -= step_time

    if (o.hit_anim && o == Player)
        o.hit_anim = false
        o.anim_kind = "hit"
        o.anim_cooldown = 10
        o.anim_frame = 0
    end
end

#// direction between two points
function get_direction(a, b)
    dx = b.x - a.x
    dy = b.y - a.y

    bits = 0

    if (dy > 0)
      bits |= 8
    elseif (dy < 0)
      bits |= 4
    end

    if (dx > 0)
      bits |= 2
    elseif (dx < 0)
      bits |= 1
    end

    return DirectionByBitfield[bits + 1]
end

function is_xy_within_active_range(xy)
    one_screen_width = Camera.view_width
    one_screen_height = Camera.view_height
    min_x = Camera.position.x - one_screen_width
    max_x = Camera.position.x + one_screen_width * 2
    min_y = Camera.position.y - one_screen_height
    max_y = Camera.position.y + one_screen_height * 2
    return xy.x >= min_x && xy.x < max_x &&
           xy.y >= min_y && xy.y < max_y
end

function vAdd(v, v2)
    return TPointF(v.x+v2.x, v.y+v2.y)
end

function vSub(v, v2)
    return TPointF(v.x-v2.x, v.y-v2.y)
end

function vMag(v)
    return sqrt(v.x*v.x+v.y*v.y)
end

function vNorm(v)
    if (v.x == 0 && v.y == 0)
        return v #// KK
    end
    mag = vMag(v)
    return TPointF(
        v.x / mag,
        v.y / mag
    )
end

function vScale(v, sc)
    return TPointF(v.x*sc, v.y*sc);
end

function draw_entities_debug()
    if (!Config["flags.draw_entities_debug"])
        return
    end
    top_left_world_xy = get_top_left_world_xy()
    top_left_cell_xy = world_to_cell_xy(top_left_world_xy)
    draw_entity_debug_enabled = true
    if (draw_entity_debug_enabled)
        for j in 0:Camera.view_height_in_cells + 1
            for i in 0:Camera.view_width_in_cells + 1
                cell_xy = TPointI(
                    top_left_cell_xy.x + i,
                    top_left_cell_xy.y + j,
                )
                cell = get_cell(cell_xy)

                if (cell != nothing && cell.entity != nothing && is_cell_visible(cell))
                    draw_entity_debug(cell.entity)
                end
            end
        end
    end
end

function is_cell_visible(cell)
    world_xy = cell_to_world_xy(cell.xy)
    min_x = Camera.position.x - Map.cell_size
    max_x = Camera.position.x + Camera.view_width
    min_y = Camera.position.y - Map.cell_size
    max_y = Camera.position.y + Camera.view_height
    max_y += Map.cell_size #// add another row of visibility so tops draw
    return world_xy.x >= min_x && world_xy.x < max_x &&
           world_xy.y >= min_y && world_xy.y < max_y
end

# convert tcolor to GameOne color
function gz_color(tcolor)
    return RGBA(
        tcolor.r / 255,
        tcolor.g / 255,
        tcolor.b / 255,
        tcolor.a
    )
end

function draw_entity_debug(entity)
    if (!entity.active)
        return
    end
    @assert entity.active == true
    cell_xy = entity.cell.xy
    @assert cell_xy != nothing
    #if (!cell_xy) debugger;
    cell_world_xy = cell_to_world_xy(cell_xy)
    cell_screen_xy = world_to_screen_xy(cell_world_xy)

    cell_fillstyle = nothing
    entity_square_strokestyle = nothing
    if (entity.kind == "enemy")
        entity_square_strokestyle = TColor(255,0,0,0.5)
        cell_fillstyle = TColor(255,0,0,0.2)
    elseif (entity.kind == "player")
        entity_square_strokestyle = TColor(255,255,255,1)
        cell_fillstyle = TColor(0,255,0,1)
    else
        entity_square_strokestyle = TColor(255,255,255,0.5)
        cell_fillstyle = TColor(127,127,127,1)
    end

    #Game.context.fillStyle = cell_fillstyle;
    #Game.context.fillRect(cell_screen_xy[0] + 1, cell_screen_xy[1] + 1, Map.cell_size - 2, Map.cell_size - 2);
    # draw cell
    if (entity.kind != "player")
        GameOne.draw(Rect(cell_screen_xy.x + 1, cell_screen_xy.y + 1, Map.cell_size - 2, Map.cell_size - 2), gz_color(cell_fillstyle), fill=true)
    end

    entity_screen_pos = world_to_screen_xy(entity.position)

    if (entity.kind == "enemy")
        #// draw a direction line
        if (true)
            len = 20
            x0 = entity_screen_pos.x;
            y0 = entity_screen_pos.y
            if (entity.direction != nothing)
                direction_offset = DirectionOffset[entity.direction]
                if (direction_offset != nothing)
                    x1 = x0 + direction_offset.x * len
                    y1 = y0 + direction_offset.y * len
                    GameOne.draw(Line(x0, y0, x1, y1), RGBA(1,0,0,1))
                end
            end
        end
    end

    GameOne.draw(
        Rect(entity_screen_pos.x - entity.size/2, entity_screen_pos.y - entity.size/2, entity.size, entity.size),
        gz_color(entity_square_strokestyle),
        fill=true
    )
    #// draw small square to show actual position in cell
    GameOne.draw(
        Rect(entity_screen_pos.x - 2, entity_screen_pos.y - 2, 4, 4),
        RGBA(1,1,1,0.5)
    )

    if (entity.debug_color != nothing)
        #Game.context.strokeStyle = entity.debug_color;
        #Game.context.beginPath();
        #Game.context.rect(entity_screen_pos[0] - entity.size/2, entity_screen_pos[1] - entity.size/2, entity.size, entity.size);
        #Game.context.stroke();
        GameOne.draw(
            Rect(entity_screen_pos.x - entity.size/2, entity_screen_pos.y - entity.size/2, entity.size, entity.size),
            gz_color(entity.debug_color),
            fill=true
        )
    end
end

function is_game_button(name)
    game_buttons = Dict(
        "LEFT" => true,
        "UP" => true,
        "RIGHT" => true,
        "DOWN" => true,
        "W" => true,
        "A" => true,
        "S" => true,
        "D" => true,
        "MouseLeft" => true,
        "MouseMiddle" => true,
        "MouseRight" => true,
        "P" => true,
        "LEFTBRACKET" => true,
        "RIGHTBRACKET" => true,
    )
    return game_buttons[name] == true
end

function on_key_down(key)
    push!(Game.button_events, TButtonEvent("down", string(key)))
end

function on_key_up(key)
    push!(Game.button_events, TButtonEvent("up", string(key)))
end

function on_mouse_down(pos, button)
    #println("on_mouse_down", button)
    if button == GameOne.MouseButtons.LEFT
        name = "MouseLeft"
        return on_key_down(name)
    end
end

function on_mouse_up(pos, button)
    #println("on_mouse_up", button)
    if button == GameOne.MouseButtons.LEFT
        name = "MouseLeft"
        return on_key_up(name)
    end
end

#// key_event = ['down', e.key]
function process_button_events()
    #// frame resets
    #empty!(Game.buttons_went_down) # not doing this in julia

    for button_event in Game.button_events
        kind = button_event.kind
        key = button_event.key
        if (kind == "down")
            Game.buttons_down[key] = true
        elseif (kind == "up")
            Game.buttons_down[key] = false
        else
            @assert false, "unexpected key_event kind", kind
        end
    end
    empty!(Game.button_events) #// reset
end

function get_aim_vector()
    return vNorm(vSub(Game.mouse_world_xy, Player.position))
end

function get_aim_angle()
    v = get_aim_vector()
    return atan(v.y, v.x) + pi
end

function add_bullet(start_xy, direction, speed, health, damage, angle)
    @assert start_xy.x >= 0 || start_xy.x < 0
    @assert start_xy.y >= 0 || start_xy.y < 0
    #//console.assert(position[0] >= 0 || position[0] < 0);
    #//console.assert(position[1] >= 0 || position[1] < 0);
    j = find_empty_slot(Bullets)

    if (j == nothing)
        #// no slot, add one
        o = TBullet();
        fill_bullet(o, start_xy, direction, speed, health, damage, angle)
        o.i = length(Bullets) + 1;
        push!(Bullets, o)
    else
        @assert Bullets[j] != nothing
        #// else, add to slot
        #//o.i = j;
        fill_bullet(Bullets[j], start_xy, direction, speed, health, damage, angle)
    end

    #//console.assert(o.start_xy[0] >= 0 || o.start_xy[0] < 0);
    #//console.assert(o.start_xy[1] >= 0 || o.start_xy[1] < 0);
    #//console.assert(o.position[0] >= 0 || o.position[0] < 0);
    #//console.assert(o.position[1] >= 0 || o.position[1] < 0);
    #//console.log('added bullet', o);
end

function update_bullets()
    if (!Config["flags.update_bullets"]) return; end
    for i in 1:length(Bullets)
        o = Bullets[i];
        @assert o != nothing
        #console.assert(m_v8.HasFastProperties(o));
        if (o.active)
            Frame.count_bullets_active += 1
            update_bullet(o)
        else
            Frame.count_bullets_not_active += 1
        end
    end
end

function cleanup_bullets()
    for i in 1:length(Bullets)
        o = Bullets[i]
        @assert o != nothing
        #console.assert(m_v8.HasFastProperties(o));
        if (
            o.pending_deactivation ||
            o.position.x < 0 || o.position[1] < 0 ||
            o.position.x >= Map.width || o.position.y >= Map.height ||
            ( Config["flags.deactivate_distant_bullets"] && !is_xy_within_active_range(o.position) )
        )
            Bullets[o.i].active = false
        end
    end
end

function update_bullet(o)
    #console.assert(m_v8.HasFastProperties(o));
    @assert o.active
    velocity = vScale(o.direction, o.speed)
    o.position_prev = o.position
    o.position = vAdd(o.position, velocity)

    update_bullet_collisions(o)

    sort_bullet_collisions(o)

    for i in 1:length(o.collisions)
        if (o.pending_deactivation) break; end

        entity = o.collisions[i]

        function find_by_id(el)
            #println("* ", el, entity.i)
            return el == entity.i
        end
        already_collided = length(findall(find_by_id, o.previous_collision_ids)) > 0
        if (already_collided) continue; end

        if (entity.kind == "enemy" || entity.kind == "wall")
            if (entity.kind == "enemy")
                entity.tint_cooldown = 20
            elseif (entity.kind == "wall")
                entity.tint_cooldown = 20
            end

            entity.health -= o.damage
            o.health -= 1
            push!(o.previous_collision_ids, entity.i)
        end

        if (o.health <= 0)
            o.pending_deactivation = true
        end
    end

    #// reset
    empty!(o.collisions) #o.collisions.length = 0
end

function fill_bullet(a, start_xy, direction, speed, health, damage, angle)
    a.start_xy.x = start_xy.x
    a.start_xy.y = start_xy.y
    a.position.x = start_xy.x
    a.position.y = start_xy.y
    a.position_prev.x = start_xy.x
    a.position_prev.y = start_xy.y
    a.direction.x = direction.x
    a.direction.y = direction.y
    a.speed = speed
    #//a.i
    a.active = true
    a.pending_deactivation = false
    empty!(a.collisions) # a.collisions.length = 0
    empty!(a.previous_collision_ids) # a.previous_collision_ids.length = 0
    a.health = health
    a.health_max = health
    a.damage = damage
    a.angle = angle
end

function is_xy_within_active_range(xy)
    one_screen_width = Camera.view_width
    one_screen_height = Camera.view_height
    min_x = Camera.position.x - one_screen_width
    max_x = Camera.position.x + one_screen_width * 2
    min_y = Camera.position.y - one_screen_height
    max_y = Camera.position.y + one_screen_height * 2
    return xy.x >= min_x && xy.x < max_x &&
           xy.y >= min_y && xy.y < max_y
end

function draw_bullets()
    for i in 1:length(Bullets)
        bullet = Bullets[i]
        if (bullet != nothing && bullet.active)

            bullet_screen_xy = world_to_screen_xy(bullet.position)

            if (Config["flags.draw_bullet_debug2"])
                #// draw small square dot
                #Game.context.fillStyle = 'rgba(255,255,255,1)';
                #Game.context.fillRect(bullet_screen_xy[0] - 3, bullet_screen_xy[1] - 3, 6, 6);
                GameOne.draw(Rect(bullet_screen_xy.x - 3, bullet_screen_xy.y - 3, 6, 6), gz_color(TColor(255,255,255,1)))

                #Game.context.fillStyle = 'rgba(150,200,255,1)';
                #Game.context.fillRect(bullet_screen_xy[0] - 2, bullet_screen_xy[1] - 2, 4, 4);
                GameOne.draw(Rect(bullet_screen_xy.x - 2, bullet_screen_xy.y - 2, 4, 4), gz_color(TColor(150,200,255,1)))

                #// draw line from prev position
                bullet_screen_xy_prev = world_to_screen_xy(bullet.position_prev)
                #Game.context.lineWidth = 4;
                #Game.context.strokeStyle = 'rgba(255,255,255,0.8)';
                #Game.context.beginPath();
                #Game.context.moveTo(bullet_screen_xy[0], bullet_screen_xy[1]);
                #Game.context.lineTo(bullet_screen_xy_prev[0], bullet_screen_xy_prev[1]);
                #Game.context.stroke();
                #Game.context.lineWidth = 1;
                GameOne.draw(Line(bullet_screen_xy.x, bullet_screen_xy.y, bullet_screen_xy_prev.x, bullet_screen_xy_prev.y), RGBA(1,1,1,0.8))
            end

            draw_bullet_debug(bullet)

            #draw_sprite(
            #    Game.context, 'weapon_arrow',
            #    bullet_screen_xy[0], bullet_screen_xy[1],
            #    16, 16,
            #    false,
            #    bullet.angle, +4, +4, 1);
            GameOne.draw(Rect(bullet_screen_xy.x - 2, bullet_screen_xy.y - 2, 4, 4), gz_color(TColor(0,255,255,1)), fill=true)
        end
    end
end

function draw_bullet_debug(bullet)
    if (!Config["flags.draw_bullet_debug"]) return; end
    #// draw line walk for debug
    bullet_cell_xy = world_to_cell_xy(bullet.position)
    bullet_cell_xy_prev = world_to_cell_xy(bullet.position_prev)
    # nolive: unported, not really needed, not hard to port though
    #line_walk(
    #    bullet_cell_xy_prev[0],
    #    bullet_cell_xy_prev[1],
    #    bullet_cell_xy[0],
    #    bullet_cell_xy[1],
    #    [true, true]
    #);
end

function update_bullets()
    if (!Config["flags.update_bullets"]) return; end
    for i in 1:length(Bullets)
        o = Bullets[i]
        @assert o != nothing
        #console.assert(m_v8.HasFastProperties(o));
        if (o.active)
            Frame.count_bullets_active += 1
            update_bullet(o)
        else
            Frame.count_bullets_not_active += 1
        end
    end
end

function cleanup_bullets()
    for i in 1:length(Bullets)
        o = Bullets[i]
        @assert o != nothing
        #console.assert(m_v8.HasFastProperties(o));
        if (
            o.pending_deactivation ||
            o.position.x < 0 || o.position.y < 0 ||
            o.position.x >= Map.width || o.position.y >= Map.height ||
            ( Config["flags.deactivate_distant_bullets"] && !is_xy_within_active_range(o.position) )
        )
            Bullets[o.i].active = false
        end
    end
end

function update_bullet_collisions(bullet)
    bullet_cell_xy = world_to_cell_xy(bullet.position)
    bullet_cell_xy_prev = world_to_cell_xy(bullet.position_prev)
    # unimplemented
    #push_line_plot(
    #    (x,y,color) => line_plot_bullet(x,y,color,bullet)
    #);
    function line_plot_closure(x, y, color)
        line_plot_bullet(x, y, color, bullet)
    end
    line_walk(
        bullet_cell_xy_prev.x,
        bullet_cell_xy_prev.y,
        bullet_cell_xy.x,
        bullet_cell_xy.y,
        [true, true],
        line_plot_closure
    )
end

function sort_bullet_collisions(bullet)
    #bullet.collisions.sort(
    #    function(a, b) { // these are entities
    #        const dist_a = manhattan_distance(bullet.start_xy, a.position);
    #        const dist_b = manhattan_distance(bullet.start_xy, b.position);
    #        //a.dist_from_bullet = dist_a; // debug
    #        //b.dist_from_bullet = dist_b;
    #        return dist_a - dist_b;
    #    }
    #)
    sort!(bullet.collisions, by = (
        entity -> manhattan_distance(bullet.start_xy, entity.position)
    ))
end

function manhattan_distance(a, b)
    dx = b.x - a.x
    dy = b.y - a.y
    return abs(dx) + abs(dy)
end

function line_plot_bullet(x, y, color, bullet)
    @assert bullet.active
    #//line_plot_original(x, y, color);
    cell = get_cell2(x, y)
    if (cell != nothing && cell.entity != nothing && cell.entity.active)
        #=/*let is_intersect = line_segment_intersects_rectangle(
            bullet.position_prev[0], bullet.position_prev[1],
            bullet.position[0], bullet.position[1],
            RectangleP(cell.entity.position[0] - 4, cell.entity.position[1] - 4, 8, 8)
        );*/=#
        is_intersect = isRectangleIntersectedByLine(
            cell.entity.position.x - cell.entity.size/2,
            cell.entity.position.y - cell.entity.size/2,
            cell.entity.position.x + cell.entity.size/2,
            cell.entity.position.y + cell.entity.size/2,
            bullet.position_prev.x,
            bullet.position_prev.y,
            bullet.position.x,
            bullet.position.y
        );
        #//is_intersect = true;
        if (is_intersect)
            push!(bullet.collisions, cell.entity)
        else
            #//console.log('NOT is_intersect', cell.entity);
        end
    end
end

#// https://stackoverflow.com/a/18046673/159022
function isRectangleIntersectedByLine(a_rectangleMinX, a_rectangleMinY, a_rectangleMaxX, a_rectangleMaxY, a_p1x, a_p1y, a_p2x, a_p2y)

    #// Find min and max X for the segment
    minX = a_p1x;
    maxX = a_p2x;

    if (a_p1x > a_p2x)
      minX = a_p2x
      maxX = a_p1x
    end

    #// Find the intersection of the segment's and rectangle's x-projections
    if (maxX > a_rectangleMaxX)
      maxX = a_rectangleMaxX
    end

    if (minX < a_rectangleMinX)
      minX = a_rectangleMinX
    end

    #// If their projections do not intersect return false
    if (minX > maxX)
      return false
    end

    #// Find corresponding min and max Y for min and max X we found before
    minY = a_p1y
    maxY = a_p2y

    dx = a_p2x - a_p1x

    if (abs(dx) > 0.0000001)
      a = (a_p2y - a_p1y) / dx
      b = a_p1y - a * a_p1x
      minY = a * minX + b
      maxY = a * maxX + b
    end

    if (minY > maxY)
      tmp = maxY
      maxY = minY
      minY = tmp
    end

    #// Find the intersection of the segment's and rectangle's y-projections
    if (maxY > a_rectangleMaxY)
      maxY = a_rectangleMaxY
    end

    if (minY < a_rectangleMinY)
      minY = a_rectangleMinY
    end

    #// If Y-projections do not intersect return false
    if (minY > maxY)
      return false
    end

    return true

end

function line_walk7b(x0, y0, x1, y1, crap_bools, line_plot)
    if (line_plot == nothing)
        line_plot = line_plot_default
    end
    function setPixelAA(x, y, i)
        a = 1-i/255
        line_plot(Int64(x), Int64(y), TColor(255,255,0,a/2))
    end

    function setPixel(x, y)
        line_plot(Int64(x), Int64(y), TColor(255,255,0,0.5))
    end

    function plotLineAA(x0, y0, x1, y1)
        #/* draw a black (0) anti-aliased line on white (255) background */
       dx = abs(x1-x0)
       sx = x0 < x1 ? 1 : -1
       dy = abs(y1-y0)
       sy = y0 < y1 ? 1 : -1
       #err = dx-dy, e2, x2                               #/* error value e_xy */
       err = dx-dy
       ed = dx+dy == 0 ? 1 : sqrt(dx*dx+dy*dy)

       while true                                                 #/* pixel loop */
          setPixelAA(x0,y0, 255*abs(err-dx+dy)/ed);
          e2 = err; x2 = x0;
          if (2*e2 >= -dx)                                            #/* x step */
             if (x0 == x1) break; end
             if (e2+dy < ed) setPixelAA(x0,y0+sy, 255*(e2+dy)/ed); end
             err -= dy
             x0 += sx
          end
          if (2*e2 <= dy)                                             #/* y step */
             if (y0 == y1) break; end
             if (dx-e2 < ed) setPixelAA(x2+sx,y0, 255*(dx-e2)/ed); end
             err += dx
             y0 += sy
          end
        end
    end

    th = 2

   #/* plot an anti-aliased line of width th pixel */
   dx = abs(x1-x0)
   sx = x0 < x1 ? 1 : -1
   dy = abs(y1-y0)
   sy = y0 < y1 ? 1 : -1
   err = nothing
   e2 = sqrt(dx*dx+dy*dy)                            #/* length */

   if (th <= 1 || e2 == 0) return plotLineAA(x0,y0, x1,y1); end         #/* assert */
   dx *= 255/e2; dy *= 255/e2; th = 255*(th-1);               #/* scale values */

   if (dx < dy)                                                #/* steep line */
      x1 = round((e2+th/2)/dy)                          #/* start offset */
      err = x1*dy-th/2                  #/* shift error value to offset width */
      #for (x0 -= x1*sx; ; y0 += sy) {
      x0 -= x1*sx
      while true
         x1 = x0
         setPixelAA(x1, y0, err)                  #/* aliasing pre-pixel */
         #for (e2 = dy-err-th; e2+dy < 255; e2 += dy)
         e2 = dy-err-th
         while e2 + dy < 255
            x1 += sx
            setPixel(x1, y0)                      #/* pixel on the line */
            e2 += dy # loop increment
         end
         setPixelAA(x1+sx, y0, e2)                    #/* aliasing post-pixel */
         if (y0 == y1) break; end
         err += dx                                                 #/* y-step */
         if (err > 255) err -= dy; x0 += sx; end                    #/* x-step */
         y0 += sy # loop increment
      end
   else                                                      #/* flat line */
      y1 = round((e2+th/2)/dx)                          #/* start offset */
      err = y1*dx-th/2                  #/* shift error value to offset width */
      #for (y0 -= y1*sy; ; x0 += sx) {
      y0 -= y1*sy
      while true
         y1 = y0
         setPixelAA(x0, y1, err)                  #/* aliasing pre-pixel */
         #for (e2 = dx-err-th; e2+dx < 255; e2 += dx)
         e2 = dx-err-th
         while e2+dx < 255
            y1 += sy
            setPixel(x0, y1)                      #/* pixel on the line */
            e2 += dx # loop increment
         end
         setPixelAA(x0, y1+sy, e2)                    #/* aliasing post-pixel */
         if (x0 == x1) break; end
         err += dy                                                 #/* x-step */
         if (err > 255) err -= dx; y0 += sy; end                    #/* y-step */
         x0 += sx # loop increment
      end
   end
end

function line_plot_default(x, y, color)
    cell_world_xy = cell_to_world_xy(TPointI(x, y))
    cell_screen_xy = world_to_screen_xy(cell_world_xy)

    if (color == nothing)
        color = TColor(255,255,0,0.5)
    end
    #Game.context.fillStyle = color;
    #Game.context.fillRect(cell_screen_xy[0], cell_screen_xy[1], Map.cell_size, Map.cell_size);
    GameOne.draw(Rect(cell_screen_xy.x, cell_screen_xy.y, Map.cell_size, Map.cell_size), gz_color(color), fill=true)
end

line_walk = line_walk7b

init()

#end # module Hordewave