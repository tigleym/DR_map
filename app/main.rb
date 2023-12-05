require 'app/constants.rb'
require 'app/rect.rb'
require 'app/tile.rb'

def tick args
  if args.state.tick_count == 0
    init_game args
  end
  tick_game args
end

def init_game args
  # setup defaults
  args.state.grid.padding = 100
  args.state.grid.size = 512
  args.state.map.tiles ||= []
  args.state.map.rooms ||= []
  args.state.map.quads ||= []
  args.state.player.direction ||= 1
  args.state.player.current_quad ||= 0

  args.state.border_x = args.state.grid.padding - TILE_SIZE
  args.state.border_y = args.state.grid.padding - TILE_SIZE
  args.state.border_size = args.state.grid.size + TILE_SIZE * 2

  # render tiles
  # first let's create the map
  if args.state.map.tiles == []
    for coordX in 0..MAP_WIDTH do
      for coordY in 0..MAP_HEIGHT - 1 do
        new_tile = Tile.new(coordX, coordY)
        new_tile.wall
        args.state.map.tiles << new_tile
      end
    end

    # generate rooms
    number_of_rooms = (MIN_ROOMS..MAX_ROOMS).to_a.sample
    loop do
      # random width and height
      w = (MIN_ROOM_SIZE..MAX_ROOM_SIZE).to_a.sample
      h = (MIN_ROOM_SIZE..MAX_ROOM_SIZE).to_a.sample
      # random position without going out of the boundaries of the map
      boundsX = MAP_WIDTH - w
      boundsY = MAP_HEIGHT - h

      x = (0..boundsX).to_a.sample
      y = (0..boundsY).to_a.sample

      # create the room and check if it intersects with already existing rooms. If it
      # doesn't, store it.
      new_room = Rect.new(x, y, w, h)

      is_intersecting = args.state.map.rooms.find do |room|
        new_room.intersects_with(room)
      end

      if !is_intersecting
        create_room(new_room)
        args.state.map.rooms << new_room
      end

      break if args.state.map.rooms.length == number_of_rooms
    end

    args.state.map.rooms.each_with_index do |room, index|
      if index > 0
        current_x, current_y = room.center
        prev_x, prev_y = args.state.map.rooms[index - 1].center

        if [true, false].sample
          # draw a horizontal corridor first, then vertical
          create_h_tunnel(prev_x, current_x, prev_y)
          create_v_tunnel(prev_y, current_y, current_x)
        else
          # draw a vertical corridor first, then horizontal
          create_v_tunnel(prev_y, current_y, prev_x)
          create_h_tunnel(prev_x, current_x, current_y)
        end
      end
    end

    # Make sure we cover up any passable tiles lying on the edge bounds of the map, or
    # have a wall both in the adjacent quandrant and tile
    for tile in args.state.map.tiles do
      adj_edge_tile = Tile.new(0, 0)
      adj_edge_tile.empty

      if !tile.passable && tile.x == 16
        adj_edge_tile = args.state.map.tiles[(tile.west * MAP_WIDTH + tile.y)]
        adj_edge_tile.wall
      elsif !tile.passable && tile.y == 16
        adj_edge_tile = args.state.map.tiles[(tile.x * MAP_WIDTH + tile.south)]
        adj_edge_tile.wall
      elsif !tile.passable && tile.x == 15
        adj_edge_tile = args.state.map.tiles[(tile.east * MAP_WIDTH + tile.y)]
        adj_edge_tile.wall
      elsif !tile.passable && tile.y == 15
        adj_edge_tile = args.state.map.tiles[(tile.x * MAP_WIDTH + tile.north)]
        adj_edge_tile.wall
      elsif tile.passable && (tile.x == 0 || tile.x == 31 || tile.y == 0 || tile.y == 31)
        adj_edge_tile = args.state.map.tiles[(tile.x * MAP_WIDTH + tile.y)]
        adj_edge_tile.wall
      end
    end

    # organize tiles into four quads
    #quad1
    args.state.map.quads << args.state.map.tiles.select { |t| t.x < 16 && t.y < 16 }
    #quad2
    args.state.map.quads << args.state.map.tiles.select { |t| (t.x >= 16 && t.x < 32) && t.y < 16 }
    #quad3
    args.state.map.quads << args.state.map.tiles.select { |t| t.x < 16 && t.y >= 16 }
    #quad4
    args.state.map.quads << args.state.map.tiles.select { |t| (t.x >= 16 && t.x < 32) && t.y >= 16 }
  end
end

def tick_game args
  for tile in args.state.map.quads[args.state.player.current_quad] do
    if tile.passable
      args.outputs.sprites << tile_in_game(tile.x.mod(16), tile.y.mod(16), "sprites/tiles/floor_1.png")
    else
      args.outputs.sprites << tile_in_game(tile.x.mod(16), tile.y.mod(16), "sprites/tiles/wall_mid.png")
    end
  end

  # place the player in the center of the first room
  first_room = args.state.map.rooms.find do |r|
    center = r.center
    center[0] < 16 && center[1] < 16
  end

  args.state.player.x ||= first_room.center[0]
  args.state.player.y ||= first_room.center[1]

  # place enemies
  args.state.enemies ||= [
    { x: 10, y: 10, type: :goblin, tile_key: :G },
    { x: 9, y: 6, type: :rat, tile_key: :R },
  ]

  args.state.info_message ||= "Use arrow keys to move around."

  # keyboard input
  new_player_x = args.state.player.x
  new_player_y = args.state.player.y
  player_direction = ""
  player_moved = false
  if args.inputs.keyboard.key_down.up
    new_player_y += 1
    player_direction = "north"
    player_moved = true
  elsif args.inputs.keyboard.key_down.down
    new_player_y -= 1
    player_direction = "south"
    player_moved = true
  elsif args.inputs.keyboard.key_down.right
    new_player_x += 1
    player_direction = "east"
    player_moved = true
    args.state.player.direction = 1
  elsif args.inputs.keyboard.key_down.left
    new_player_x -= 1
    player_direction = "west"
    player_moved = true
    args.state.player.direction = -1
  end

  # game logic
  # determine if there is an enemy on that square,
  # if so, don't let the player move there
  if player_moved
    found_enemy = args.state.enemies.find do |e|
      e[:x] == new_player_x && e[:y] == new_player_y
    end

    found_wall = args.state.map.tiles.find do |t|
      !t.passable && t.x == new_player_x && t.y == new_player_y
    end

    out_of_bounds = new_player_x < 0 || new_player_x >= 32 || new_player_y < 0 || new_player_y >= 32

    if !found_enemy && !found_wall && !out_of_bounds
      args.state.player.x = new_player_x
      args.state.player.y = new_player_y
      args.state.info_message = "You moved #{player_direction}."
    else
      args.state.info_message = "You cannot move here."
    end

    # check if player is...
    # moving into quad 1
    if args.state.player.x < 16 && args.state.player.y < 16
      args.state.player.current_quad = 0
    # moving into quad 2
    elsif args.state.player.x >= 16 && args.state.player.y < 16
      args.state.player.current_quad = 1
    # moving into quad 3
    elsif args.state.player.x < 16 && args.state.player.y >= 16
      args.state.player.current_quad = 2
     # moving into quad 4
    elsif args.state.player.x >= 16 && args.state.player.y >= 16
      args.state.player.current_quad = 3
    end
  end

  # render actors
  # render player
  frame = get_sprite_frame(args)
  args.outputs.sprites << tile_in_game(args.state.player.x.mod(16),
  args.state.player.y.mod(16), "sprites/player/elf_m_idle_anim_f#{frame}.png", args.state.player.direction)

  # render enemies at locations
  args.outputs.sprites << args.state.enemies.map do |e|
    tile_in_game(e[:x].mod(16), e[:y].mod(16), "sprites/enemies/big_demon_idle_anim_f#{frame}.png")
  end

  # render label stuff
  args.outputs.labels << [args.state.border_x, args.state.border_y - 30, "Frame rate: #{args.gtk.current_framerate}"]
  args.outputs.labels << [args.state.border_x, args.state.border_y - 10, "Current player location is: #{args.state.player.x}, #{args.state.player.y}"]
  args.outputs.labels << [args.state.border_x + 500, args.state.border_y - 10, "Sprite count: #{args.sprites.size}"]
  args.outputs.labels << [args.state.border_x + 500, args.state.border_y - 30, "Current Quad: #{args.state.player.current_quad}"]
  args.outputs.labels << [args.state.border_x + 1000, args.state.border_y - 10, "# of Rooms: #{args.state.map.rooms.length}"]
  args.outputs.labels << [args.state.border_x, args.state.border_y + 25 + args.state.border_size, args.state.info_message]
end

def tile_in_game (x, y, sprite_path, flip = 1)
    {
      x: $gtk.args.state.grid.padding + x * TILE_SIZE,
      y: $gtk.args.state.grid.padding + y * TILE_SIZE,
      w: TILE_SIZE,
      h: TILE_SIZE,
      path: sprite_path,
      flip_horizontally: flip < 0
    }
end

def get_sprite_frame args
  return args.state.tick_count.idiv(10).mod(4)
end

def create_room rect
  # go through the tiles in the rectangle and make them passable
  for x in rect.x1..rect.x2 do
    for y in rect.y1..rect.y2 do
      $gtk.args.state.map.tiles[x * MAP_WIDTH + y].empty
    end
  end
end

def create_h_tunnel x1, x2, y
  for x in [x1, x2].min..[x1, x2].max do
    $gtk.args.state.map.tiles[x * MAP_WIDTH + y].empty
  end
end

def create_v_tunnel y1, y2, x
  for y in [y1, y2].min..[y1, y2].max do
    $gtk.args.state.map.tiles[x * MAP_WIDTH + y].empty
  end
end
