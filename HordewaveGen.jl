import ..Hordewave

#module HordewaveGen

struct TEnemyInfo
    health :: Int64
    speed :: Int64
end

function generate()
    Map = Hordewave.Map
    randomInt = Hordewave.randomInt
    TPointF = Hordewave.TPointF
    TEntity = Hordewave.TEntity

    enemy_info = Dict(
        "goblin" => TEnemyInfo(1, 3),
        "tiny_zombie" => TEnemyInfo(2, 3),
        "imp" => TEnemyInfo(1, 3),
        "skelet" => TEnemyInfo(1, 2),
        "muddy" => TEnemyInfo(4, 1),
        "swampy" => TEnemyInfo(4, 1),
        "zombie" => TEnemyInfo(3, 2),
        "ice_zombie" => TEnemyInfo(4, 2),
        "masked_orc" => TEnemyInfo(5, 2),
        "orc_warrior" => TEnemyInfo(6, 1),
        "orc_shaman" => TEnemyInfo(6, 1),
        "necromancer" => TEnemyInfo(8, 2),
        "wogol" => TEnemyInfo(10, 4),
    )

    julia_mult = 1
    for i in 1:1000 * julia_mult
        o = Hordewave.TEntity("enemy")
        sub_kinds = [
            "goblin", "tiny_zombie", "imp", "skelet", "muddy", "swampy", "zombie",
            "goblin", "tiny_zombie", "imp", "skelet", "muddy", "swampy", "zombie",

            "ice_zombie", "masked_orc", "orc_warrior", "orc_shaman",
            "ice_zombie", "masked_orc", "orc_warrior", "orc_shaman",

            "necromancer", "wogol",
            #"chort", "big_zombie", "ogre", "big_demon"
        ]
        o.anim_kind = "idle"
        o.anim_frame = 0
        o.anim_cooldown = 30
        o.sub_kind = sub_kinds[ Hordewave.randomInt(1, length(sub_kinds)) ]
        o.health = enemy_info[o.sub_kind].health

        position = Hordewave.TPointF(
            rand() * (Hordewave.Map.width-1),
            rand() * (Hordewave.Map.height-1),
        );
        info_speed = enemy_info[o.sub_kind].speed;
        o.speed = Hordewave.randomInt(1,6) / 12 * info_speed;
        o.size = Hordewave.Map.cell_size;

        slang_entity(o, position);
    end

    use_old_stuff = true

    if (use_old_stuff)

        for i in 1:100
            o = Hordewave.TEntity("wall")
            o.sub_kind = "column_mid"
            o.health = 15
            position = TPointF(
                randomInt(0, Map.width_in_cells - 1) * Map.cell_size + Map.cell_size/2,
                randomInt(0, Map.height_in_cells - 1) * Map.cell_size + Map.cell_size/2
            )

            slang_entity(o, position)
        end

        # -------

        wall_subkinds1 = [
            "wall_left",
            "wall_mid",
            "wall_right",
            "wall_hole_1",
            "wall_hole_2",
            "wall_banner_red",
            "wall_banner_blue",
            "wall_banner_green",
            "wall_banner_yellow",
        ];

        #for i in 1:1000
        for i in 1:600

            x_start = randomInt(0, Map.width_in_cells - 1) * Map.cell_size + Map.cell_size/2;
            y_start = randomInt(0, Map.height_in_cells - 1) * Map.cell_size + Map.cell_size/2;

            for j in 1:4
                x_now = x_start + j * Map.cell_size;
                if (x_now > Map.width) continue; end

                o = TEntity("wall");
                o.health = 20
                rando =  randomInt(1, length(wall_subkinds1));
                o.sub_kind = wall_subkinds1[rando];
                @assert o.sub_kind != nothing
                position = TPointF(
                    x_now,
                    y_start,
                )
                slang_entity(o, position)
            end
        end

    end

end

function slang_entity(o, position)
    #console.assert(o.sub_kind);
    prefill_cell = Hordewave.get_cell_for_position(position)
    if (prefill_cell.entity == nothing)
        o.cell = prefill_cell; # this is just so the set can assert that entity has a cell during normal set_entity_position calls
        Hordewave.set_entity_position(o, position)
        Hordewave.add_entity(o)
    else
        # dont add if entity already there
    end
end

#end # module HordewaveGen