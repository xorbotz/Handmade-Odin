package main

import "core:fmt"
import "core:math"

debug_mode: bool = true
Game_Mem: ^game_memory
mapcountx: i32 : 17
mapcounty: i32 : 9


world: World = {
	TileSideM       = 1.4,
	TileSidePixels  = 70.0,
	Upperleftstarty = 5.0,
	Upperleftstartx = 5.0,
}
tile_map: [2][2]Map
worldSizeY: i32 : 2
worldSizeX: i32 : 2
worldSize: [2]int : {2, 2}


game_memory :: struct {
	isInit:               bool,
	Permanentstoragesize: u64,
	PermanentStorage:     rawptr,
	Transientstoragesize: u64,
	Transientstorage:     rawptr,
}

thread_context :: struct {
	temp: i32,
}
global_position :: struct {
	TileMapX:    i32,
	TileMapY:    i32,
	TileX:       i32,
	TileY:       i32,
	TileOffsetX: f32,
	TileOffsetY: f32,
}
Recon_Position :: #force_inline proc(Player_Position: ^global_position) {

	if Player_Position.TileOffsetX < 0 {
		Player_Position.TileX -= 1
		Player_Position.TileOffsetX = world.TileSidePixels + Player_Position.TileOffsetX

	} else if Player_Position.TileOffsetX > world.TileSidePixels {
		Player_Position.TileX += 1
		Player_Position.TileOffsetX -= world.TileSidePixels

	}
	if Player_Position.TileOffsetY < 0 {
		Player_Position.TileY -= 1
		Player_Position.TileOffsetY = world.TileSidePixels + Player_Position.TileOffsetY

	} else if Player_Position.TileOffsetY > world.TileSidePixels {
		Player_Position.TileY += 1
		Player_Position.TileOffsetY -= world.TileSidePixels

	}
	if Player_Position.TileY == mapcounty {
		fmt.println("Moving Down")
		Player_Position.TileMapY += 1

		fmt.println("Current Y: ", world.currenty)
		Player_Position.TileY = 0 // world.TileSidePixels + 5
	} else if Player_Position.TileY == 0 && Player_Position.TileOffsetY <= 40 { 	//f32(world.TileSidePixels) {
		fmt.println("Moving up")
		Player_Position.TileMapY -= 1
		fmt.println("Current Y: ", world.currenty)
		Player_Position.TileY = mapcounty - 1
	} else if Player_Position.TileX == mapcountx {
		fmt.println("Moving Right")
		Player_Position.TileMapX += 1

		fmt.println("Current x ", world.currentx)
		Player_Position.TileX = 0 //world.Upperleftstartx + 1 //world.TileSidePixels + 5
	} else if Player_Position.TileX == 0 &&
	   Player_Position.TileOffsetX <= world.Upperleftstartx { 	//f32(world.TileSidePixels) {
		fmt.println("Moving Left")
		Player_Position.TileMapX -= 1
		fmt.println("Current X: ", world.currentx)
		Player_Position.TileX = mapcountx - 1
		//GameState.PlayerX = f32(world.TileSidePixels) + world.TileSidePixels * f32((mapcountx - 1))
	}


}

game_state :: struct {
	Player_Position: global_position,
	PlayerX:         f32,
	PlayerY:         f32,
	p1Jump:          f32,
	p1JumpStart:     i32,
	fhJump:          bool,
}
World :: struct {
	maps:            [^]Map,
	currentx:        int,
	currenty:        int,
	Upperleftstartx: f32,
	Upperleftstarty: f32,
	TileSidePixels:  f32,
	TileSideM:       f32,
	MapWidth:        i32,
}
Map :: struct {
	countx:   i32,
	county:   i32,
	MapWidth: i32,
	Tilemap:  [^]int,
}

game_button_state :: struct {
	HalfTransitionCount: int,
	EndedDown:           bool,
}

dist_to_pixelx :: #force_inline proc(map1: ^Map, dist: f32) -> f32 {
	return .01 * f32(world.TileSidePixels)
	//return f32(dist / 100 * map1.TileWdit * mapcountx)

}

dist_to_pixely :: #force_inline proc(map1: ^Map, dist: f32) -> f32 {
	return f32(world.TileSidePixels)
	//return f32(dist / 100 * map1.TileWdit * mapcounty)

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


	//Color: u32 = 0x0000FFFF
	Color: u32 = 0xffff00ff

	Rowz: [^]u8 = cast([^]u8)Buffer.memory
	//Rowz:^u8 = cast(^u8)Bitmapmemory
	Pitch := Buffer.Pitch
	//Pitch:=4*width
	for y: i32 = minY; y < maxY; y += 1 {
		Pixel: [^]u32 = cast([^]u32)Rowz
		for x: i32 = minX; x < maxX; x += 1 {
			Pixel[(y * Pitch) + x] = final
		}
		//    Rowz = mem.ptr_offset(Rowz,Pitch)"min
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
	//Rowz:^u8 = cast(^u8)Bitmapmemory
	Pitch := Buffer.Pitch
	//Pitch:=4*width
	if Top >= 0 && Top + SpriteW < Buffer.Height {
		for y: i32 = Top; y <= Bottom + 1; y += 1 {
			Pixel: [^]u32 = cast([^]u32)Rowz
			for x: i32 = Left; x <= Right; x += 1 {
				Pixel[(y * Pitch) + x] = Color
			}
			//    Rowz = mem.ptr_offset(Rowz,Pitch)
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
		//Note do didigtal stuff
		if GameState.p1Jump > 0 {
			//		GameState.PlayerY = i32(
			//			f32(GameState.PlayerY) - 4.0 * GameState.p1Jump * GameState.p1Jump,
			//		) //*math.sin_f32(GameState.p1Jump*math.PI*.5))
		} else {

			//		GameState.PlayerY = i32(
			//			f32(GameState.PlayerY) + 2.0 * GameState.p1Jump * GameState.p1Jump,
			//		) //*math.sin_f32(GameState.p1Jump*math.PI*.5))
		}
		//GameState.PlayerY = i32(f32(GameState.PlayerY))// +10.0*math.sin_f32(GameState.p1Jump))
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
			dPlayerY = 4.0
		};if buttons.Left.EndedDown {
			dPlayerX = -4.0
		};if buttons.Up.EndedDown {

			dPlayerY = -4.0
		};if buttons.Right.EndedDown {

			dPlayerX = 4.0
		}
		if buttons.Action1.EndedDown {
			fmt.println("Action1")
			if GameState.p1Jump == 0 {
				GameState.p1Jump = 1.0
				//		GameState.p1JumpStart = GameState.PlayerY
				GameState.fhJump = true
			}

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
	movementScale: f32 = 64.0


	//NewPlayerX := GameState.PlayerX + dtForFrame * movementScale * dPlayerX //+ dist_to_pixelx(map1, dPlayerX) //+ dtForFrame * movementScale * dPlayerX
	//NewPlayerY := GameState.PlayerY + dtForFrame * movementScale * dPlayerY //dist_to_pixely(map1, dPlayerY) //+ dtForFrame * movementScale * dPlayerY
	NewPlayerX := GameState.Player_Position.TileOffsetX + dtForFrame * movementScale * dPlayerX //+ dist_to_pixelx(map1, dPlayerX) //+ dtForFrame * movementScale * dPlayerX
	NewPlayerY := GameState.Player_Position.TileOffsetY + dtForFrame * movementScale * dPlayerY //dist_to_pixely(map1, dPlayerY) //+ dtForFrame * movementScale * dPlayerY
	P1 := GameState.Player_Position
	P2 := GameState.Player_Position
	P3 := GameState.Player_Position
	P1.TileOffsetX = NewPlayerX
	P1.TileOffsetY = NewPlayerY

	P2.TileOffsetX = NewPlayerX
	P2.TileOffsetY = NewPlayerY

	P3.TileOffsetX = NewPlayerX
	P3.TileOffsetY = NewPlayerY

	Recon_Position(&P1)
	Recon_Position(&P2)
	Recon_Position(&P3)


	if IsWorldMapPointEmpty(&P1) && IsWorldMapPointEmpty(&P2) && IsWorldMapPointEmpty(&P3) {

		GameState.Player_Position = P1
		world.currentx = int(GameState.Player_Position.TileMapX)
		world.currenty = int(GameState.Player_Position.TileMapY)

		/*
		GameState.PlayerX = NewPlayerX

		GameState.PlayerY = NewPlayerY
		x, y := getTile(world, GameState.PlayerX, GameState.PlayerY)
		fmt.println("Player Y: ", GameState.PlayerY, "Y tile: ", y)
		if y == mapcounty {
			fmt.println("Moving Down")
			world.currenty += 1

			fmt.println("Current Y: ", world.currenty)
			GameState.PlayerY = world.TileSidePixels + 5
		} else if y == 0 && GameState.PlayerY <= 40 { 	//f32(world.TileSidePixels) {
			fmt.println("Moving up")
			world.currenty -= 1
			fmt.println("Current Y: ", world.currenty)
			GameState.PlayerY =
				f32(world.TileSidePixels) + world.TileSidePixels * f32((mapcounty - 1))
		} else if x == mapcountx {
			fmt.println("Moving Right")
			world.currentx += 1

			fmt.println("Current x ", world.currentx)
			GameState.PlayerX = world.Upperleftstartx + 1 //world.TileSidePixels + 5
		} else if x == 0 && GameState.PlayerX <= world.Upperleftstartx { 	//f32(world.TileSidePixels) {
			fmt.println("Moving Left")
			world.currentx -= 1
			fmt.println("Current X: ", world.currentx)
			GameState.PlayerX =
				f32(world.TileSidePixels) + world.TileSidePixels * f32((mapcountx - 1))
		}
		*/

	}


}

getTile :: #force_inline proc(world: ^World, TestfX: f32, TestfY: f32) -> (i32, i32) {

	map1 := &world.maps[world.currenty * int(worldSizeX) + world.currentx]
	TestX := i32((TestfX - world.Upperleftstartx) / world.TileSidePixels)
	TestY := i32((TestfY - world.Upperleftstarty) / world.TileSidePixels)
	return TestX, TestY

}

IsWorldMapPointEmpty :: proc(
	Player_Pos: ^global_position,
	//world: ^World,
	//TestfX: f32,
	//TestfY: f32,
	//GameState: ^game_state,
) -> bool {

	map1 := &world.maps[Player_Pos.TileMapY * i32(worldSizeX) + Player_Pos.TileMapX]
	if IsMapPointEmpty(map1, Player_Pos.TileX, Player_Pos.TileY) {

		return true
	}
	return false

	//TODO posibly make this a proc! 
	/*
	map1 := &world.maps[world.currenty * int(worldSizeX) + world.currentx]

	TestX := i32((TestfX - world.Upperleftstartx) / world.TileSidePixels)
	TestY := i32((TestfY - world.Upperleftstarty) / world.TileSidePixels)
	TempX := TestX
	TempY := TestY

	tempxw := world.currentx
	tempyw := world.currenty

	if TestX < 0 && world.currentx > 0 {
		map1 = &world.maps[world.currenty * int(worldSizeX) + world.currentx - 1]
		TempX = mapcountx - 1
		fmt.println("TestX: ", TestX, "TempX: ", TempX)
	} else if TestX == mapcountx && world.currentx != int(worldSizeX) {
		map1 = &world.maps[world.currenty * int(worldSizeX) + world.currentx + 1]
		TempX = 0

	} else if TestY < 0 && world.currenty > 0 {
		map1 = &world.maps[(world.currenty - 1) * int(worldSizeX) + world.currentx]
		TempY = mapcounty - 1
		fmt.println("TestY: ", TestY, "TempY: ", TempY)
	} else if TestY == mapcounty && world.currentx != int(worldSizeY) {

		fmt.println("TestY: ", TestY)
		//map1 = &world.maps[1]
		map1 = &world.maps[(world.currenty + 1) * int(worldSizeX) + world.currentx]
		TempY = 0
		//map1 = &world.maps[tempy * int(worldSizeX) + tempx] // * int(worldSizeX) + world.currentx]
	}


	if IsMapPointEmpty(map1, TempX, TempY) {

		if TestY == mapcounty - 1 {
			fmt.println("returnint true")
		}
		return true
	}
	return false
	*/

}
IsMapPointEmpty :: proc(map1: ^Map, TestX: i32, TestY: i32) -> bool {
	PlayerTileX := TestX
	PlayerTileY := TestY


	if PlayerTileX >= 0 &&
	   PlayerTileX < (mapcountx) &&
	   PlayerTileY >= 0 &&
	   PlayerTileY < (mapcounty) {
		if map1.Tilemap[PlayerTileY * mapcountx + PlayerTileX] != 1 {
			//fmt.println("Clean")
			return true
		}

	}
	return false

}

@(export)
game_hot_reloaded :: proc(mem: ^game_memory) {
	Game_Mem = mem
}
@(export)
game_init :: proc(PSs: u64, PS: rawptr, TSS: u64, TS: rawptr) {
	Game_Mem = new(game_memory)
	Game_Mem.Permanentstoragesize = PSs
	Game_Mem.PermanentStorage = PS

	Game_Mem.Transientstoragesize = TSS
	Game_Mem.Transientstorage = TS
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
	GameState: ^game_state = cast(^game_state)Memory.PermanentStorage
	// file_name:= "C:/Users/robotics/CLionProjects/Handmade-Odin/src/lol.txt"
	file_name := "src/lol.txt"
	file_name_w := "src/test1.txt"


	if !Memory.isInit {
		//TODO This should almost certainly just be 1 multipointer but have to cross that bridge later
		Memory.isInit = true
		//DeleteFileData(Bitmapdata, Bitmapmemory)
		GameState.PlayerX = 650
		GameState.PlayerY = 500
		GameState.Player_Position.TileX = 5
		GameState.Player_Position.TileY = 5
		world.currenty = 0
		world.currentx = 0
	}


	//RenderPlayer(Buffer, GameState.PlayerX, GameState.PlayerY)
	//RenderPlayer(Buffer, Input.MouseX, Input.MouseY)

	//TODO May want to move this all to a flattened array - I probably want to just move this to some fixed memory location as well - almost certainly anohtner file just called maps
	Tilemap_dummy: [mapcounty][mapcountx]int = {
		{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	}

	Tilemap_0: [mapcounty][mapcountx]int = {
		{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
		{1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		{1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		{1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1},
		{1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1},
		{1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1},
		{1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1},
	}
	Tilemap_1: [mapcounty][mapcountx]int = {
		{1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		{1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		{1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	}

	Tilemap_2: [mapcounty][mapcountx]int = {
		{1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	}
	Tilemap_3: [mapcounty][mapcountx]int = {
		{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
		{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		{1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1},
	}


	tile_map[0][0].Tilemap = ([^]int)(&Tilemap_0) //(raw_data(&Tilemap))
	tile_map[0][0].countx = mapcountx
	tile_map[0][0].county = mapcounty

	tile_map[0][1] = tile_map[0][0]
	tile_map[0][1].Tilemap = ([^]int)(&Tilemap_3)

	tile_map[1][0] = tile_map[0][0]
	tile_map[1][0].Tilemap = ([^]int)(&Tilemap_1)

	tile_map[1][1] = tile_map[0][0]
	tile_map[1][1].Tilemap = ([^]int)(&Tilemap_2)

	/*temp := make_multi_pointer(
		[^]Map(mapcounty, mapcountx),
		mapcounty * mapcountx,
		context.allocator,
	)*/


	temp := cast([^]Map)(&tile_map)


	world.maps = temp //([^]Map(mapcounty, mapcountx))(&tile_map)


	for &controller in Input.Controllers {
		HandleInput(
			GameState,
			&controller,
			Buffer.Height,
			Buffer.Width,
			Input.dtForFrame,
			&tile_map[world.currenty][world.currentx],
			&world,
		)
	}


	DrawRect(Buffer, 0, 0, f32(Buffer.Width), f32(Buffer.Height), 0, 0, 0)
	//fmt.println(world.currenty, world.currentx)
	for i in 0 ..< mapcounty {
		for j in 0 ..< mapcountx {
			color: f32 = .5
			//fmt.println(i, j)

			Tileid := tile_map[world.currenty][world.currentx].Tilemap[i * mapcountx + j]
			if Tileid == 1 {
				color = 1.0
			}
			minX := f32(j) * world.TileSidePixels + world.Upperleftstartx
			minY := f32(i) * world.TileSidePixels + world.Upperleftstarty
			maxX := minX + world.TileSidePixels
			maxY := minY + world.TileSidePixels

			DrawRect(Buffer, minX, minY, maxX, maxY, color, color, color)
		}
	}
	PlayerR: f32 = 1.0
	PlayerG: f32 = 1.0
	PlayerB: f32 = 0.0
	PlayerW := .75 * world.TileSidePixels
	//.75 * tile_map[world.currenty][world.currentx].TileWidt
	PlayerH := world.TileSidePixels

	PlayerL: f32 =
		f32(GameState.Player_Position.TileX) * world.TileSidePixels +
		GameState.Player_Position.TileOffsetX -
		.5 * world.TileSidePixels
	PlayerT: f32 =
		f32(GameState.Player_Position.TileY) * world.TileSidePixels +
		GameState.Player_Position.TileOffsetY -
		PlayerH
	//	if PlayerT < tile_map[world.currenty][world.currentx].Upperleftstarty {
	//		PlayerT = tile_map[world.currenty][world.currentx].Upperleftstarty
	//	}

	fmt.println(
		"OffsetX: ",
		GameState.Player_Position.TileOffsetX,
		"OffsetY: ",
		GameState.Player_Position.TileOffsetY,
	)
	DrawRect(
		Buffer,
		PlayerL,
		PlayerT,
		PlayerL + PlayerW,
		PlayerT + PlayerH,
		PlayerR,
		PlayerG,
		PlayerB,
	)
	return true

}
