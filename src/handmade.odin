package main
import "core:slice"

import "core:encoding/endian"
import "core:fmt"
import "core:math"
import "core:os"

import "core:mem"

debug_mode: bool = true
Game_Mem: ^game_memory
GameState: ^game_state
tile_map: ^Map
world: ^World

windowSizey: u32 : 9
windowSizex: u32 : 17


bmp :: struct {
	FileType:  u16,
	FileSize:  u32,
	somename:  u16,
	somename2: u16,
	Offset:    u32,
	width:     i32,
	height:    i32,
	Planes:    u16,
	bpp:       u16,
}

game_memory :: struct {
	isInit:                bool,
	arenaInit:             bool,
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
	Left:        bool,
	Right:       bool,
	moving:      bool,
}
Get_Chunk :: #force_inline proc(world: ^World, chunk_p: ^chunk_position) -> ^Map {

	/*	if world.chunks[chunk_p.ChunkY * world.ChunkX + chunk_p.ChunkX] == nil {
		fmt.println("HERE Get Chunk", chunk_p.ChunkX, chunk_p.ChunkY)

		map1 := cast(^Map)push_Size(&GameState.arena, size_of(Map))


		mappoint: ^[32][32]i32 = cast(^[32][32]i32)push_Size(
			&GameState.arena,
			size_of([32][32]int),
		) //new([32][32]i32, Memory.PermanentStorageAlloc)


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

		map1.Tilemap = ([^]i32)(mappoint) //(raw_data(&Tilemap))

		fmt.println("Here3")
		world.chunks[chunk_p.ChunkY * world.ChunkX + chunk_p.ChunkX] = map1
	}*/


	map1 := world.chunks[chunk_p.ChunkY * world.ChunkX + chunk_p.ChunkX]
	return map1
}
Alloc_Chunk :: proc() -> ^Map {
	mapn := cast(^Map)push_Size(&GameState.arena, size_of(Map))


	mappoint: ^[32][32]i32 = cast(^[32][32]i32)push_Size(&GameState.arena, size_of([32][32]int)) //new([32][32]i32, Memory.PermanentStorageAlloc)


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

	mapn.Tilemap = ([^]i32)(mappoint) //(raw_data(&Tilemap))
	return mapn

}
Get_Tile_Value :: proc(world: ^World, chunk_p: ^chunk_position) -> i32 {

	if world.chunks[chunk_p.ChunkY * world.ChunkX + chunk_p.ChunkX] == nil {


		world.chunks[chunk_p.ChunkY * world.ChunkX + chunk_p.ChunkX] = Alloc_Chunk()
	}
	map1 := world.chunks[chunk_p.ChunkY * world.ChunkX + chunk_p.ChunkX]
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
	arena:           mem_arena,
	Player_Position: global_position,
	backGroundData:  ^[]u8,
	backGroundBmap:  ^bmp,
	playerBmap:      ^bmp,
	playerData:      ^[]u8,
	count:           u64,
	Speed:           uint,
}
World :: struct {
	chunks:          [^](^Map),
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

loadBMP :: proc(filename: string) -> (^[]u8, ^bmp) {

	file_handle, error := os.open(filename)
	if error == nil {
		file_size, _ := os.file_size(file_handle)
		file_data, file_ok := os.read_entire_file_from_filename(filename) //os.read_entire_file_from_handle(file_handle)

		if file_ok {

			os.close(file_handle)

		} else {
			//TODO this might be necessary assert(1==0)
			panic("FILE NOTE FOUND CRASHING")
		}
		bmap := cast(^bmp)push_Size(&GameState.arena, size_of(bmp))
		bmap.FileType = endian.unchecked_get_u16be(file_data[0:2]) //u16(test[0]) // << 8 + u16(test[1])
		bmap.FileSize = endian.unchecked_get_u32le(file_data[2:6])
		bmap.Offset = endian.unchecked_get_u32le(file_data[10:14])
		bmap.width, _ = endian.get_i32(file_data[18:22], .Little)
		bmap.height, _ = endian.get_i32(file_data[22:26], .Little)
		bmap.bpp = endian.unchecked_get_u16le(file_data[28:30])


		//, bitmapHeader.Offset)
		tmp := file_data[bmap.Offset:]
		bmpdata := cast(^[]u8)push_Size(&GameState.arena, size_of(tmp))
		bmpdata^ = tmp


		return bmpdata, bmap


	} else {
		fmt.println("Couldn't Load File")}
	return nil, nil

}


RenderBmp :: proc(
	img: ^bmp,
	imgData: ^[]u8,
	Buffer: ^game_offscreen_buffer,
	world: ^World,
	Left: i32,
	Top: i32,
	Width: i32,
	Height: i32,
	StartX: i32,
	StartY: i32,
) {

	Rowz: [^]u8 = cast([^]u8)Buffer.memory
	Pitch := Buffer.Pitch
	test := slice.reinterpret([]u32, imgData^)
	Bottom := Top + Height
	Right := Left + Width


	if Top >= 0 && Bottom <= Buffer.Height {
		fmt.println("rendering")
		for y: i32 = 0; y < Bottom - Top; y += 1 { 	//img.height; y += 1 {
			Pixel: [^]u32 = cast([^]u32)Rowz
			for x: i32 = 0; x < Right - Left; x += 1 { 	//img.width; x += 1 {
				//TODO FIX FOR GOING LEFT!!!!!!
				temp := test[(y + StartY) * img.width + x + StartX]
				destT := Pixel[((i32(Bottom) - y) * Pitch) + x + i32(Left)]
				sB := f32(temp & 0xFF)
				sG := f32((temp >> 8) & 0xFF)
				sR := f32((temp >> 16) & 0xFF)

				dB := f32(destT & 0xFF)
				dG := f32((destT >> 8) & 0xFF)
				dR := f32((destT >> 16) & 0xFF)

				sA := f32(((temp >> 24) & 0xFF)) / 255.0
				fB := sB //(1 - sA) * dB + sA * sB
				fG := sG //(1 - sA) * dG + sA * sG
				fR := sR //(1 - sA) * dR + sA * sR

				//fmt.println(sA, "Sa")
				final: u32 = (cast(u32)fR) << 16 | (cast(u32)fG) << 8 | cast(u32)fB


				if !GameState.Player_Position.Left {
					//	if test[(y + StartY) * img.width + x + StartX] >> 24 > 128 {

					if final != 0 {
						Pixel[((i32(Bottom) - y) * Pitch) + x + i32(Left)] = final //test[(y + StartY) * img.width + x + StartX] //}
					}
				} else {

					if test[(y + StartY) * img.width + x + StartX] >> 24 > 128 {
						Pixel[((i32(Bottom) - y) * Pitch) + Right - x] =
							test[(y + StartY) * img.width + x + StartX]
					}
				}

			}
		}
	} else {
		fmt.println("Not rendering")
	}


}


RenderBckgrnd :: proc(
	img: ^bmp,
	imgData: ^[]u8,
	Buffer: ^game_offscreen_buffer,
	world: ^World,
	GameState: ^game_state,
) {

	Left := i32(world.Upperleftstartx)
	Top := i32(world.Upperleftstarty)
	Rowz: [^]u8 = cast([^]u8)Buffer.memory
	Pitch := Buffer.Pitch
	test := slice.reinterpret([]u32, imgData^)

	for y: i32 = 0; y < img.height; y += 1 {
		Pixel: [^]u32 = cast([^]u32)Rowz
		for x: i32 = 0; x < img.width; x += 1 {
			Pixel[((i32(world.LowerLeftStartY) - y) * Pitch) + x + i32(world.Upperleftstartx)] =
				test[y * img.width + x] //& 0x004F4F4F
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
			GameState.Player_Position.Left = true
			GameState.Player_Position.Right = false
			GameState.Player_Position.moving = true


		} else {

			//GameState.Player_Position.moving = false
		}
		if buttons.Up.EndedDown {

			dPlayerY = 1.0
		};if buttons.Right.EndedDown {

			dPlayerX = 1.0
			GameState.Player_Position.Right = true
			GameState.Player_Position.Left = false

			GameState.Player_Position.moving = true

		} else {

			//GameState.Player_Position.moving = false
		}
		if !(buttons.Right.EndedDown || buttons.Left.EndedDown) {
			GameState.Player_Position.moving = false
		}
		if buttons.Action1.EndedDown {
			fmt.println("Speed")
			GameState.Speed = 1

		}

		if buttons.Action2.EndedDown {
			fmt.println("end speed")

			GameState.Speed = 0
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
	if (GameState.Speed == 1) {
		dPlayerX *= 5
		dPlayerY *= 5
	}


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

mem_arena :: struct {
	data: [^]u8,
	size: u64,
	used: u64,
}
initialize_arena :: proc(arena: ^mem_arena, size: u64, base: rawptr) {

	arena.size = size
	arena.data = cast([^]u8)base
	arena.used = 0
}

push_Size :: proc(arena: ^mem_arena, size: u64) -> rawptr {

	assert(arena.used + size <= arena.size)
	res := &arena.data[arena.used]
	arena.used = arena.used + size
	return res

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
	file_name := "C:/Users/acker/CLionProjects/Handmade-Odin/src/forest.bmp"
	//file_name := "src/lol.txt"
	file_name_w := "src/test1.txt"


	if !Memory.isInit {
		//TODO This should almost certainly just be 1 multipointer but have to cross that bridge later
		fmt.println("Initting Mem!")
		Memory.isInit = true
		//	data, bmap = 

		GameState = cast(^game_state)Memory.PermanentStorage

		initialize_arena(&GameState.arena, Memory.Permanentstoragesize, Memory.PermanentStorage)
		push_Size(&GameState.arena, size_of(game_state))
		//	GameState.arena = cast(^mem_arena)push_Size(GameState.arena, size_of(mem_arena))


		GameState.world = cast(^World)push_Size(&GameState.arena, size_of(World))

		//GameState.world = new(World, Memory.PermanentStorageAlloc) //DeleteFileData(Bitmapdata, Bitmapmemory)
		world = GameState.world
		world.TileSideM = 1.4
		world.TileSidePixels = 70.0
		world.Upperleftstarty = 5.0
		world.Upperleftstartx = 5.0
		world.LowerLeftStartX = 5.0
		world.LowerLeftStartY = 635.0

		world.MetersToPixels = world.TileSidePixels / 1.4
		world.ChunkShift = 5
		world.ChunkDim = 32
		world.ChunkX = 4
		world.ChunkY = 10

		GameState.Player_Position.AbsTileX = 10
		GameState.Player_Position.AbsTileY = 5
		world.currenty = 0
		world.currentx = 0
		world.LowerLeftStartY = f32(windowSizey) * world.TileSidePixels
		world.Window_Pos.AbsTileY = 0
		world.Window_Pos.AbsTileX = 0
		world.chunks =
		cast([^]^Map)push_Size(&GameState.arena, u64(world.ChunkX * world.ChunkY * size_of(^Map)))
		world.chunks[0] = Alloc_Chunk() //tile_map

		GameState.backGroundData, GameState.backGroundBmap = loadBMP(file_name)

		file_name = "C:/Users/acker/CLionProjects/Handmade-Odin/src/run.bmp"
		GameState.playerData, GameState.playerBmap = loadBMP(file_name)


	}


	for &controller in Input.Controllers {
		HandleInput(GameState, &controller, Buffer.Height, Buffer.Width, Input.dtForFrame, world)
	}


	//DrawRect(Buffer, 0, 0, f32(Buffer.Width), f32(Buffer.Height), 0, 0, 0)
	RenderBckgrnd(GameState.backGroundBmap, GameState.backGroundData, Buffer, world, GameState)
	/*RenderBmp(
		GameState.backGroundBmap,
		GameState.backGroundData,
		Buffer,
		world,
		i32(GameState.world.LowerLeftStartX),
		i32(GameState.world.Upperleftstarty),
		Buffer.Width - 2 * i32(GameState.world.Upperleftstartx),
		i32(GameState.world.LowerLeftStartY - GameState.world.Upperleftstarty),
	)*/

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
			color: f32 = 1.0
			Temp_Pos.AbsTileX = world.Window_Pos.AbsTileX + j
			Temp_Pos.AbsTileY = world.Window_Pos.AbsTileY + i
			current_chunk_pos := To_Chunk_Pos(&Temp_Pos, world)

			if Temp_Pos.AbsTileY == GameState.Player_Position.AbsTileY &&
			   Temp_Pos.AbsTileX == GameState.Player_Position.AbsTileX {
				//fmt.println("h Player")
				color = 0
			}


			Tileid := Get_Tile_Value(world, &current_chunk_pos) //tile_map[world.currenty][world.currentx].Tilemap[i * mapcountx + j]
			if Tileid == 1 {
				color = 1.0
				minX := f32(j) * world.TileSidePixels + world.Upperleftstartx
				minY :=
					world.LowerLeftStartY -
					f32(i + 1) * world.TileSidePixels +
					world.Upperleftstarty

				maxX := minX + world.TileSidePixels
				maxY := minY + world.TileSidePixels

				DrawRect(Buffer, minX, minY, maxX, maxY, color, color, color)
			}
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
	if GameState.Player_Position.moving {
		GameState.count += 1
	}
	if GameState.count >= 16 || !(GameState.Player_Position.moving) {
		GameState.count = 0
	}

	RenderBmp(
		GameState.playerBmap,
		GameState.playerData,
		Buffer,
		world,
		i32(math.round_f32(PlayerL)),
		i32(math.round_f32(PlayerT)),
		i32(math.round_f32(PlayerW * world.MetersToPixels) + 20),
		i32(math.round_f32(PlayerH * world.MetersToPixels)) + 40,
		64 + (i32(GameState.count) / 2) * 200,
		31,
	)


	/*DrawRect(
		Buffer,
		PlayerL,
		PlayerT,
		PlayerL + PlayerW * world.MetersToPixels,
		PlayerT + PlayerH * world.MetersToPixels,
		PlayerR,
		PlayerG,
		PlayerB,
	)*/
	return true

}
