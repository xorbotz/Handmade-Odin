package main

import "core:fmt"
import "core:math"

import "core:mem"

debug_mode: bool = true
Game_Mem: ^game_memory
GameState: game_state

world: ^World
mapcountx: i32 : 17
mapcounty: i32 : 9

windowSizey: u32 : 9
windowSizex: u32 : 17


tile_map: [2][2]Map
worldSizeY: i32 : 2
worldSizeX: i32 : 2
worldSize: [2]int : {2, 2}


game_memory :: struct {
	isInit:                bool,
	Permanentstoragesize:  u64,
	PermanentStorage:      rawptr,
	Transientstoragesize:  u64,
	Transientstorage:      rawptr,
	PermanentStorageAlloc: mem.Allocator,
}

thread_context :: struct {
	temp: i32,
}
chunk_position :: struct {
	ChunkX: u32,
	ChunkY: u32,
	TileX:  u32,
	TileY:  u32,
}

global_position :: struct {
	AbsTileX:    u32,
	AbsTileY:    u32,
	TileOffsetX: f32,
	TileOffsetY: f32,
}
Get_Chunk :: #force_inline proc(world: ^World, chunkp: ^chunk_position) -> ^Map {

	map1 := &world.chunks[chunkp.ChunkY * world.ChunkX + chunkp.ChunkX]
	return map1
}
Get_Tile_Value :: proc(world: ^World, chunk_p: ^chunk_position) -> i32 {

	map1 := &world.chunks[chunk_p.ChunkY * world.ChunkX + chunk_p.ChunkX]
	return map1.Tilemap[chunk_p.TileY * world.ChunkDim + chunk_p.TileX]
}
To_Chunk_Pos :: #force_inline proc(
	Player_Position: ^global_position,
	world: ^World,
) -> chunk_position {
	res: chunk_position
	res.ChunkX = Player_Position.AbsTileX >> world.ChunkShift
	res.ChunkY = Player_Position.AbsTileY >> world.ChunkShift
	res.TileX = Player_Position.AbsTileX & 0x1F
	res.TileY = Player_Position.AbsTileY & 0x1F
	return res

}

Recon_Position :: #force_inline proc(Player_Position: ^global_position, world: ^World) {

	if Player_Position.TileOffsetX < 0 {
		Player_Position.AbsTileX -= 1
		Player_Position.TileOffsetX = world.TileSideM + Player_Position.TileOffsetX

	} else if Player_Position.TileOffsetX > world.TileSideM {
		Player_Position.AbsTileX += 1
		Player_Position.TileOffsetX -= world.TileSideM

	}
	if Player_Position.TileOffsetY < 0 {
		Player_Position.AbsTileY -= 1
		Player_Position.TileOffsetY = world.TileSideM + Player_Position.TileOffsetY

	} else if Player_Position.TileOffsetY > world.TileSideM {
		Player_Position.AbsTileY += 1
		Player_Position.TileOffsetY -= world.TileSideM

	}

}

game_state :: struct {
	world:           ^World,
	Player_Position: global_position,
}
World :: struct {
	chunks:          [^]Map,
	currentx:        int,
	currenty:        int,
	Upperleftstartx: f32,
	Upperleftstarty: f32,
	LowerLeftStartX: f32,
	LowerLeftStartY: f32,
	TileSidePixels:  f32,
	TileSideM:       f32,
	MapWidth:        i32,
	MetersToPixels:  f32,
	ChunkShift:      u32,
	ChunkDim:        u32,
	ChunkX:          u32,
	ChunkY:          u32,
	Window_Pos:      global_position,
}
Map :: struct {
	countx:   i32,
	county:   i32,
	MapWidth: i32,
	Tilemap:  [^]i32,
}

game_button_state :: struct {
	HalfTransitionCount: int,
	EndedDown:           bool,
}


game_pad :: struct {
	Up:        game_button_state,
	Down:      game_button_state,
	Left:      game_button_state,
	Right:     game_button_state,
	Action1:   game_button_state,
	Action2:   game_button_state,
	Action3:   game_button_state,
	Action4:   game_button_state,
	LShoulder: game_button_state,
	RShoulder: game_button_state,
	Start:     game_button_state,
}

//TODO I should change this...
Buttons :: union {
	[9]game_button_state,
	game_pad,
}

game_controller_input :: struct {
	isConnected: bool,
	IsAnalgo:    bool,
	StickFramex: f32,
	StickFramey: f32,
	gamepad:     game_pad,
	padButtons:  union {
		[9]game_button_state,
		game_pad,
	},
}

game_input :: struct {
	MouseButton: [2]game_button_state,
	MouseX:      i32,
	MouseY:      i32,
	Controllers: [5]game_controller_input,
	dtForFrame:  f32,
}

game_offscreen_buffer :: struct {
	memory:               rawptr,
	Height, Width, Pitch: i32,
}


DrawRect :: proc(
	Buffer: ^game_offscreen_buffer,
	fminX: f32,
	fminY: f32,
	fmaxX: f32,
	fmaxY: f32,
	R: f32,
	G: f32,
	B: f32,
) {
	minX: i32 = i32(math.round_f32(fminX))
	maxX: i32 = i32(math.round_f32(fmaxX))
	minY: i32 = i32(math.round_f32(fminY))
	maxY: i32 = i32(math.round_f32(fmaxY))

	if minX < 0 {
		minX = 0
	};if minY < 0 {
		maxY = maxY + minY
		minY = 0
	};if maxX > Buffer.Width {
		maxX = Buffer.Width
	};if maxY > Buffer.Height {
		maxY = Buffer.Height
	}

	Blue := math.round_f32(255 * B)
	Green := math.round_f32(255 * G)
	Red := math.round_f32(255 * R)
	final: u32 = (cast(u32)Red) << 16 | (cast(u32)Green) << 8 | cast(u32)Blue


	Color: u32 = 0xffff00ff

	Rowz: [^]u8 = cast([^]u8)Buffer.memory
	Pitch := Buffer.Pitch
	for y: i32 = minY; y < maxY; y += 1 {
		Pixel: [^]u32 = cast([^]u32)Rowz
		for x: i32 = minX; x < maxX; x += 1 {
			Pixel[(y * Pitch) + x] = final
		}
	}

}
RenderPlayer :: proc(Buffer: ^game_offscreen_buffer, PlayerX: i32, PlayerY: i32) {
	SpriteW: i32 = 10
	Color: u32 = 0xFFFFFFFF
	Left: i32 = PlayerX
	Right: i32 = Left + SpriteW
	Top := PlayerY
	Bottom: i32 = Top + SpriteW
	Rowz: [^]u8 = cast([^]u8)Buffer.memory
	Pitch := Buffer.Pitch
	if Top >= 0 && Top + SpriteW < Buffer.Height {
		for y: i32 = Top; y <= Bottom + 1; y += 1 {
			Pixel: [^]u32 = cast([^]u32)Rowz
			for x: i32 = Left; x <= Right; x += 1 {
				Pixel[(y * Pitch) + x] = Color
			}
		}
	}
}

RenderWeirdGradient :: proc(Buffer: ^game_offscreen_buffer, GameState: ^game_state) {

	/*
	Rowz: [^]u8 = cast([^]u8)Buffer.memory
	//Rowz:^u8 = cast(^u8)Bitmapmemory
	Pitch := Buffer.Pitch
	//Pitch:=4*width
	for y: i32 = 0; y < Buffer.Height; y += 1 {
		Pixel: [^]u32 = cast([^]u32)Rowz
		for x: i32 = 0; x < Buffer.Width; x += 1 {
			Blue := u8(GameState.Blue) * cast(u8)(x + GameState.offsetX)
			Green := u8(GameState.Green) * cast(u8)(y + GameState.offsetY)

			Red: u8 = u8(GameState.Red) * cast(u8)(y + GameState.offsetY)
			// (cast(u32)Red<<8|
			final: u32 = (cast(u32)Red) << 16 | (cast(u32)Green) << 8 | cast(u32)Blue
			Pixel[(y * Pitch) + x] = final
		}
		//    Rowz = mem.ptr_offset(Rowz,Pitch)
	}
	*/
}

game_output_sound_buffer :: struct {
	SamplesPerSecond: u32,
	SampleCount:      u32,
	SampleOut:        [^]i32,
	ToneHz:           u32,
}

GameOutputSound :: proc(SoundBuffer: ^game_output_sound_buffer, ToneHz: u32) {
	if !debug_mode {
		Soundlevel: i16 = 600
		SquareWavePeriod: u32 = 48000 / ToneHz
		for SampleIndex: u32 = 0; SampleIndex < SoundBuffer.SampleCount; SampleIndex += 1 {
			SampleValue: i16 =
				((u32(SampleIndex) / cast(u32)SquareWavePeriod / 2) % 2) == 0 ? Soundlevel : -1 * Soundlevel
			temp := cast(i32)SampleValue
			temp = temp << 16
			temp2 := i32(i32(SampleValue) & 0b00000000000000001111111111111111)
			final := temp | temp2
			SoundBuffer.SampleOut[SampleIndex] = final
		}
	}
}

HandleInput :: proc(
	GameState: ^game_state,
	Input1: ^game_controller_input,
	Height: i32,
	Width: i32,
	dtForFrame: f32,
	map1: ^Map,
	world: ^World,
) {
	if (Input1.IsAnalgo) {
		//	GameState.PlayerX += i32(4.0 * Input1.StickFramex)
		//	GameState.PlayerY -= i32(
		//		4.0 * Input1.StickFramey + 10.0 * (GameState.p1Jump) * GameState.p1Jump,
		//	)

	} else {
	}
	/*
	if (GameState.PlayerY < GameState.p1JumpStart && GameState.p1Jump != 0) {
		GameState.p1Jump -= .03
	} else if GameState.PlayerY >= GameState.p1JumpStart && GameState.fhJump == true {
		GameState.p1Jump = 0
		//GameState.PlayerY = GameState.p1JumpStart
		GameState.fhJump = false
	}
	*/

	//This is the digital part of the analog stick... can handle a bunch of ways
	dPlayerX: f32 = 0.0
	dPlayerY: f32 = 0.0
	switch buttons in Input1.padButtons {
	case game_pad:
		if buttons.Down.EndedDown {
			dPlayerY = -1.0
		};if buttons.Left.EndedDown {
			dPlayerX = -1.0
		};if buttons.Up.EndedDown {

			dPlayerY = 1.0
		};if buttons.Right.EndedDown {

			dPlayerX = 1.0
		}
		if buttons.Action1.EndedDown {
			fmt.println("Action1")

		}

		if buttons.Action2.EndedDown {
			fmt.println("Action2")
		}
		//push please

		if buttons.Action3.EndedDown {
			fmt.println("Action3")
		}

		if buttons.Action4.EndedDown {
			fmt.println("Action4")
		}
	case [9]game_button_state:
		if buttons[0].EndedDown {
		}

	}
	dPlayerX *= 5.0 //m/s
	dPlayerY *= 5.0 //m/s


	NewPlayerX := GameState.Player_Position.TileOffsetX + dtForFrame * dPlayerX //+ dist_to_pixelx(map1, dPlayerX) //+ dtForFrame * movementScale * dPlayerX
	NewPlayerY := GameState.Player_Position.TileOffsetY + dtForFrame * dPlayerY //dist_to_pixely(map1, dPlayerY) //+ dtForFrame * movementScale * dPlayerY

	P1 := GameState.Player_Position
	P2 := GameState.Player_Position
	P3 := GameState.Player_Position

	P1.TileOffsetX = NewPlayerX
	P1.TileOffsetY = NewPlayerY + .2

	P2.TileOffsetX = NewPlayerX - .52 * world.TileSideM
	P2.TileOffsetY = NewPlayerY + .2

	P3.TileOffsetX = NewPlayerX + .5 * .25 * world.TileSideM
	P3.TileOffsetY = NewPlayerY + .2

	Recon_Position(&P1, world)
	Recon_Position(&P2, world)
	Recon_Position(&P3, world)

	if IsWorldMapPointEmpty(world, &P1) &&
	   IsWorldMapPointEmpty(world, &P2) &&
	   IsWorldMapPointEmpty(world, &P3) {

		P1.TileOffsetY -= .2
		GameState.Player_Position = P1
	}
}

getTile :: #force_inline proc(world: ^World, TestfX: f32, TestfY: f32) -> (i32, i32) {

	map1 := world.chunks[world.currenty * int(worldSizeX) + world.currentx]
	TestX := i32((TestfX - world.Upperleftstartx) / world.TileSidePixels)
	TestY := i32((TestfY - world.Upperleftstarty) / world.TileSidePixels)
	return TestX, TestY

}

IsWorldMapPointEmpty :: proc(world: ^World, Player_Pos: ^global_position) -> bool {

	//if Player_Pos.TileMapX >= 0 && Player_Pos.TileMapY >= 0 {
	chunkp := To_Chunk_Pos(Player_Pos, world)
	map1 := Get_Chunk(world, &chunkp) ///&world.maps[Player_Pos.TileMapY * i32(worldSizeX) + Player_Pos.TileMapX]
	return IsMapPointEmpty(world, map1, chunkp.TileX, chunkp.TileY)
}

IsMapPointEmpty :: proc(world: ^World, map1: ^Map, TestX: u32, TestY: u32) -> bool {
	PlayerTileX := TestX
	PlayerTileY := TestY


	if map1.Tilemap[PlayerTileY * world.ChunkDim + PlayerTileX] != 1 {
		return true
	}


	return false

}

@(export)
game_hot_reloaded :: proc(mem: ^game_memory) {
	Game_Mem = mem
}
@(export)
game_init :: proc(PSs: u64, PS: rawptr, TSS: u64, TS: rawptr, PS_Alloc: ^mem.Allocator) {
	Game_Mem = new(game_memory)
	Game_Mem.Permanentstoragesize = PSs
	Game_Mem.PermanentStorage = PS

	Game_Mem.Transientstoragesize = TSS
	Game_Mem.Transientstorage = TS
	Game_Mem.PermanentStorageAlloc = PS_Alloc^
}
@(export)
game_sd :: proc() {
	free(Game_Mem)
}
@(export)
game_mem_ptr :: proc() -> rawptr {
	return Game_Mem
}
@(export)
game_GameGetSoundSamples :: proc(
	Thread: ^thread_context,
	Memory: ^game_memory,
	SoundBuffer: ^game_output_sound_buffer,
) -> bool {
	GameState: ^game_state = cast(^game_state)Memory.PermanentStorage
	//GameOutputSound(SoundBuffer, GameState.ToneHz)
	return true
}

@(export)
game_GameUpdateAndRender :: proc(
	Thread: ^thread_context,
	Memory: ^game_memory,
	Input: ^game_input,
	Buffer: ^game_offscreen_buffer,
) -> bool {
	//TODO Possibly implement the game to be told where in time to put sound
	Input0: ^game_controller_input = &Input.Controllers[0]
	Input1: ^game_controller_input = &Input.Controllers[1]
	//GameState: ^game_state = cast(^game_state)Memory.PermanentStorage
	// file_name:= "C:/Users/robotics/CLionProjects/Handmade-Odin/src/lol.txt"
	file_name := "src/lol.txt"
	file_name_w := "src/test1.txt"


	if !Memory.isInit {
		//TODO This should almost certainly just be 1 multipointer but have to cross that bridge later
		Memory.isInit = true
		//DeleteFileData(Bitmapdata, Bitmapmemory)
		GameState.world = new(World, Memory.PermanentStorageAlloc)
		world = GameState.world
		world.TileSideM = 1.4
		world.TileSidePixels = 70.0
		world.Upperleftstarty = 5.0
		world.Upperleftstartx = 5.0
		world.LowerLeftStartX = 5.0
		world.LowerLeftStartY = 635.0

		world.MetersToPixels = 70.0 / 1.4
		world.ChunkShift = 5
		world.ChunkDim = 32
		world.ChunkX = 2
		world.ChunkY = 2

		GameState.Player_Position.AbsTileX = 10
		GameState.Player_Position.AbsTileY = 5
		world.currenty = 0
		world.currentx = 0
		world.LowerLeftStartY = f32(mapcounty) * world.TileSidePixels
		world.Window_Pos.AbsTileY = 0
		world.Window_Pos.AbsTileX = 0
		mappoint: ^[32][32]i32 = new([32][32]i32, Memory.PermanentStorageAlloc)


		//TODO May want to move this all to a flattened array - I probably want to just move this to some fixed memory location as well - almost certainly anohtner file just called maps
		for i := 0; i < 32; i += 1 {
			for j := 0; j < 32; j += 1 {
				if i == 0 || i == 31 {
					mappoint^[i][j] = 1
				} else if j == 0 || j == 31 {

					mappoint^[i][j] = 1
				} else if i % 3 == 0 && j % 5 == 0 {

					mappoint^[i][j] = 1
				} else {
					mappoint^[i][j] = 0
				}

			}
		}
		mappoint^[31][9] = 0
		mappoint^[31][10] = 0
		mappoint^[0][9] = 0
		mappoint^[0][10] = 0
		mappoint^[9][0] = 0
		mappoint^[12][0] = 0
		mappoint^[11][0] = 0
		mappoint^[10][0] = 0
		mappoint^[9][31] = 0
		mappoint^[10][31] = 0
		mappoint^[11][31] = 0
		mappoint^[12][31] = 0


		tile_map[0][0].Tilemap = ([^]i32)(mappoint) //(raw_data(&Tilemap))
		tile_map[0][0].countx = mapcountx
		tile_map[0][0].county = mapcounty

		tile_map[0][1] = tile_map[0][0]

		tile_map[1][0] = tile_map[0][0]

		tile_map[1][1] = tile_map[0][0]


		temp := cast([^]Map)(&tile_map)
		world.chunks = temp


		/*
		m1: Map
		m1.Tilemap = ([^]i32)(mappoint)

		world.chunks[0] = m1 //tile_map[0][0] //= temp //([^]Map(mapcounty, mapcountx))(&tile_map)
		world.chunks[1] = m1
		world.chunks[2] = m1
		world.chunks[3] = m1
		*/

	}


	for &controller in Input.Controllers {
		HandleInput(
			&GameState,
			&controller,
			Buffer.Height,
			Buffer.Width,
			Input.dtForFrame,
			&tile_map[world.currenty][world.currentx],
			world,
		)
	}


	DrawRect(Buffer, 0, 0, f32(Buffer.Width), f32(Buffer.Height), 0, 0, 0)

	Temp_Pos := world.Window_Pos


	if GameState.Player_Position.AbsTileY > world.Window_Pos.AbsTileY &&
	   GameState.Player_Position.AbsTileY - world.Window_Pos.AbsTileY >= windowSizey {
		world.Window_Pos.AbsTileY += windowSizey
	} else if i32(GameState.Player_Position.AbsTileY) - i32(world.Window_Pos.AbsTileY) < 0 {
		world.Window_Pos.AbsTileY -= windowSizey
	}
	if GameState.Player_Position.AbsTileX > world.Window_Pos.AbsTileX &&
	   GameState.Player_Position.AbsTileX - world.Window_Pos.AbsTileX >= windowSizex {
		world.Window_Pos.AbsTileX += windowSizex
	} else if i32(GameState.Player_Position.AbsTileX) - i32(world.Window_Pos.AbsTileX) < 0 {
		world.Window_Pos.AbsTileX -= windowSizex}


	for i: u32 = 0; i < windowSizey; i += 1 {

		for j: u32 = 0; j < windowSizex; j += 1 {
			color: f32 = .5
			Temp_Pos.AbsTileX = world.Window_Pos.AbsTileX + j
			Temp_Pos.AbsTileY = world.Window_Pos.AbsTileY + i
			current_chunk_pos := To_Chunk_Pos(&Temp_Pos, world)
			fmt.println(
				"Window X:",
				world.Window_Pos.AbsTileX,
				"Window X:",
				world.Window_Pos.AbsTileY,
				"GameStateAbsY",
				GameState.Player_Position.AbsTileX,
				"GameStateAbsY",
				GameState.Player_Position.AbsTileY,
				"GameCunkx:",
				To_Chunk_Pos(&GameState.Player_Position, world).ChunkX,
				"GameChunkY",
				To_Chunk_Pos(&GameState.Player_Position, world).ChunkY,
			)
			if Temp_Pos.AbsTileY == GameState.Player_Position.AbsTileY &&
			   Temp_Pos.AbsTileX == GameState.Player_Position.AbsTileX {
				fmt.println("Drawing Player")
				color = 0
			}


			Tileid := Get_Tile_Value(world, &current_chunk_pos) //tile_map[world.currenty][world.currentx].Tilemap[i * mapcountx + j]
			if Tileid == 1 {
				color = 1.0
			}
			minX := f32(j) * world.TileSidePixels + world.Upperleftstartx
			minY :=
				world.LowerLeftStartY - f32(i + 1) * world.TileSidePixels + world.Upperleftstarty

			maxX := minX + world.TileSidePixels
			maxY := minY + world.TileSidePixels

			DrawRect(Buffer, minX, minY, maxX, maxY, color, color, color)
		}
	}
	PlayerR: f32 = 1.0
	PlayerG: f32 = 1.0
	PlayerB: f32 = 0.0
	PlayerW: f32 = .75 * world.TileSideM
	//.75 * tile_map[world.currenty][world.currentx].TileWidt
	PlayerH := world.TileSideM

	PlayerL: f32 =
		f32(GameState.Player_Position.AbsTileX - world.Window_Pos.AbsTileX) *
			world.TileSidePixels -
		.5 * (world.MetersToPixels * PlayerW) +
		world.MetersToPixels * GameState.Player_Position.TileOffsetX


	PlayerT: f32 =
		world.LowerLeftStartY -
		f32(GameState.Player_Position.AbsTileY - world.Window_Pos.AbsTileY + 1) *
			world.TileSidePixels -
		world.MetersToPixels * GameState.Player_Position.TileOffsetY

	DrawRect(
		Buffer,
		PlayerL,
		PlayerT,
		PlayerL + PlayerW * world.MetersToPixels,
		PlayerT + PlayerH * world.MetersToPixels,
		PlayerR,
		PlayerG,
		PlayerB,
	)
	return true

}
