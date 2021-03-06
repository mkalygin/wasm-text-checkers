;; Learning sources:
;; https://pragprog.com/titles/khrust/programming-webassembly-with-rust/
;; https://rustwasm.github.io/book
;; https://github.com/sunfishcode/wasm-reference-manual
;; https://developer.mozilla.org/en-US/docs/WebAssembly/Understanding_the_text_format
;; https://openhome.cc/eGossip/WebAssembly/index.html
;; https://blog.scottlogic.com/2018/04/26/webassembly-by-hand.html
;; https://evilmartians.com/chronicles/hands-on-webassembly-try-the-basics

(module
  (import "events" "piecemoved"
    (func $notify_piecemoved (param $from_x i32) (param $from_y i32) (param $to_x i32) (param $to_y i32)))
  (import "events" "piececrowned"
    (func $notify_piececrowned (param $x i32) (param $y i32)))

  ;; 8x8 i32 linear board
  ;; 4 bytes per square
  ;; 8 * 4 = 32 bytes per row
  ;; 32 * 8 = 256 bytes per board
  (memory $mem 1)

  ;; 0cwb
  ;; c - is crowned
  ;; w - is white
  ;; b - is black
  ;; 0000 - unoccupied
  ;; 0001 - occupied by black
  ;; 0010 - occupied by white
  ;; 0101 - occupied by crowned black
  (global $EMPTY i32 (i32.const 0))
  (global $BLACK i32 (i32.const 1))
  (global $WHITE i32 (i32.const 2))
  (global $BLACK_OR_WHITE i32 (i32.const 3))
  (global $CROWN i32 (i32.const 4))
  (global $current_player (mut i32) (i32.const 1))

  ;; calculates offset in memory for a given position (x, y)
  (func $offset_for_position (param $x i32) (param $y i32) (result i32)
    (i32.mul
      (i32.const 4)
      (i32.add
        (i32.mul
          (i32.const 8)
          (get_local $y))
        (get_local $x)))
  )

  ;; checks if a piece is crowned
  (func $is_crowned (param $piece i32) (result i32)
    (i32.eq
      (i32.and (get_local $piece) (get_global $CROWN))
      (get_global $CROWN))
  )

  ;; checks if a piece is black
  (func $is_black (param $piece i32) (result i32)
    (i32.eq
      (i32.and (get_local $piece) (get_global $BLACK))
      (get_global $BLACK))
  )

  ;; checks if a piece is white
  (func $is_white (param $piece i32) (result i32)
    (i32.eq
      (i32.and (get_local $piece) (get_global $WHITE))
      (get_global $WHITE))
  )

  ;; adds a crown to a piece
  (func $with_crown (param $piece i32) (result i32)
    (i32.or
      (get_local $piece)
      (get_global $CROWN))
  )

  ;; removes a crown from a piece
  (func $without_crown (param $piece i32) (result i32)
    (i32.and
      (get_local $piece)
      (get_global $BLACK_OR_WHITE))
  )

  ;; checks if a coordinate is within the board's range
  (func $is_in_range (param $coord i32) (result i32)
    (i32.and
      (i32.ge_s (get_local $coord) (i32.const 0))
      (i32.le_s (get_local $coord) (i32.const 7)))
  )

  ;; gets a piece at (x, y) coordinate
  (func $get_piece (param $x i32) (param $y i32) (result i32)
    (if (result i32)
      (i32.and
        (call $is_in_range (get_local $x))
        (call $is_in_range (get_local $y)))
    (then
      (i32.load
        (call $offset_for_position (get_local $x) (get_local $y))))
    (else
      (unreachable)))
  )

  ;; sets a piece at (x, y) coordinate
  (func $set_piece (param $x i32) (param $y i32) (param $piece i32)
    (if
      (i32.and
        (call $is_in_range (get_local $x))
        (call $is_in_range (get_local $y)))
    (then
      (i32.store
        (call $offset_for_position (get_local $x) (get_local $y))
        (get_local $piece)))
    (else
      (unreachable)))
  )

  ;; checks if a piece belongs to the current player
  (func $is_current_player_piece (param $piece i32) (result i32)
    (i32.eq
      (i32.and
        (call $get_current_player)
        (get_local $piece))
      (call $get_current_player))
  )

 ;; gets the current player
  (func $get_current_player (result i32)
    (get_global $current_player)
  )

  ;; sets the current player
  (func $set_current_player (param $player i32)
    (set_global $current_player (get_local $player))
  )

  ;; toggles the current player
  (func $toggle_current_player
    (if
      (i32.eq (call $get_current_player) (get_global $BLACK))
    (then
      (call $set_current_player (get_global $WHITE)))
    (else
      (call $set_current_player (get_global $BLACK))))
  )

  ;; check if a piece should be crowned
  (func $should_crown_piece (param $x i32) (param $y i32) (result i32)
    (local $piece i32)
    (set_local $piece (call $get_piece (get_local $x) (get_local $y)))

    (i32.or
      (i32.and
        (call $is_white (get_local $piece))
        (i32.eq (get_local $y) (i32.const 7)))
      (i32.and
        (call $is_black (get_local $piece))
        (i32.eq (get_local $y) (i32.const 0))))
  )

  ;; add a crown to a piece at (x, y) coordinate
  (func $crown_piece (param $x i32) (param $y i32)
    (local $piece i32)
    (set_local $piece (call $get_piece (get_local $x) (get_local $y)))
    (set_local $piece (call $with_crown (get_local $piece)))

    (call $set_piece (get_local $x) (get_local $y) (get_local $piece))

    (call $notify_piececrowned (get_local $x) (get_local $y))
  )

  ;; a piece can move by 1 square in any direction if the target position
  ;; is not occupied and the piece belongs to the current player
  (func $is_valid_move (param $from_x i32) (param $from_y i32) (param $to_x i32) (param $to_y i32) (result i32)
    (local $piece i32)
    (local $target i32)

    (set_local $piece (call $get_piece (get_local $from_x) (get_local $from_y)))
    (set_local $target (call $get_piece (get_local $to_x) (get_local $to_y)))

    (i32.and
      (call $is_valid_move_distance
        (get_local $from_x) (get_local $from_y)
        (get_local $to_x) (get_local $to_y))
      (i32.and
        (call $is_current_player_piece (get_local $piece))
        (i32.eq (get_local $target) (get_global $EMPTY))))
  )

  (func $is_valid_move_distance (param $from_x i32) (param $from_y i32) (param $to_x i32) (param $to_y i32) (result i32)
    (local $diff_x i32)
    (local $diff_y i32)

    (set_local $diff_x (i32.sub (get_local $from_x) (get_local $to_x)))
    (set_local $diff_y (i32.sub (get_local $from_y) (get_local $to_y)))

    (i32.and
      (i32.and
        (i32.ge_s (get_local $diff_x) (i32.const -1))
        (i32.le_s (get_local $diff_x) (i32.const 1)))
      (i32.and
        (i32.ge_s (get_local $diff_y) (i32.const -1))
        (i32.le_s (get_local $diff_y) (i32.const 1))))
  )

  ;; moves a piece at a given coordinated if possible
  (func $move_piece (param $from_x i32) (param $from_y i32) (param $to_x i32) (param $to_y i32) (result i32)
    (if (result i32)
      (call $is_valid_move
        (get_local $from_x) (get_local $from_y)
        (get_local $to_x) (get_local $to_y))
    (then
      (call $perform_piece_move
        (get_local $from_x) (get_local $from_y)
        (get_local $to_x) (get_local $to_y)))
    (else
      (i32.const 0)))
  )

  (func $perform_piece_move (param $from_x i32) (param $from_y i32) (param $to_x i32) (param $to_y i32) (result i32)
    (local $piece i32)

    (set_local $piece (call $get_piece (get_local $from_x) (get_local $from_y)))
    (call $set_piece (get_local $to_x) (get_local $to_y) (get_local $piece))
    (call $set_piece (get_local $from_x) (get_local $from_y) (get_global $EMPTY))

    (if
      (call $should_crown_piece (get_local $to_x) (get_local $to_y))
    (then
      (call $crown_piece (get_local $to_x) (get_local $to_y))))

    (call $notify_piecemoved (get_local $from_x) (get_local $from_y) (get_local $to_x) (get_local $to_y))

    (call $toggle_current_player)

    (i32.const 1)
  )

  (func $init_board
    (local $x i32)
    (local $y i32)

    ;; reset all squares
    (set_local $x (i32.const 0))

    (loop $x_loop
      (set_local $y (i32.const 0))

      (loop $y_loop
        (call $set_piece (get_local $x) (get_local $y) (get_global $EMPTY))
        (set_local $y (i32.add (get_local $y) (i32.const 1)))
        (br_if $y_loop (i32.le_s (get_local $y) (i32.const 7))))

      (set_local $x (i32.add (get_local $x) (i32.const 1)))
      (br_if $x_loop (i32.le_s (get_local $x) (i32.const 7))))

    ;; set 12 white pieces
    (call $set_piece (i32.const 1) (i32.const 0) (get_global $WHITE))
    (call $set_piece (i32.const 3) (i32.const 0) (get_global $WHITE))
    (call $set_piece (i32.const 5) (i32.const 0) (get_global $WHITE))
    (call $set_piece (i32.const 7) (i32.const 0) (get_global $WHITE))
    (call $set_piece (i32.const 0) (i32.const 1) (get_global $WHITE))
    (call $set_piece (i32.const 2) (i32.const 1) (get_global $WHITE))
    (call $set_piece (i32.const 4) (i32.const 1) (get_global $WHITE))
    (call $set_piece (i32.const 6) (i32.const 1) (get_global $WHITE))
    (call $set_piece (i32.const 1) (i32.const 2) (get_global $WHITE))
    (call $set_piece (i32.const 3) (i32.const 2) (get_global $WHITE))
    (call $set_piece (i32.const 5) (i32.const 2) (get_global $WHITE))
    (call $set_piece (i32.const 7) (i32.const 2) (get_global $WHITE))

    ;; set 12 black pieces
    (call $set_piece (i32.const 0) (i32.const 7) (get_global $BLACK))
    (call $set_piece (i32.const 2) (i32.const 7) (get_global $BLACK))
    (call $set_piece (i32.const 4) (i32.const 7) (get_global $BLACK))
    (call $set_piece (i32.const 6) (i32.const 7) (get_global $BLACK))
    (call $set_piece (i32.const 1) (i32.const 6) (get_global $BLACK))
    (call $set_piece (i32.const 3) (i32.const 6) (get_global $BLACK))
    (call $set_piece (i32.const 5) (i32.const 6) (get_global $BLACK))
    (call $set_piece (i32.const 7) (i32.const 6) (get_global $BLACK))
    (call $set_piece (i32.const 0) (i32.const 5) (get_global $BLACK))
    (call $set_piece (i32.const 2) (i32.const 5) (get_global $BLACK))
    (call $set_piece (i32.const 4) (i32.const 5) (get_global $BLACK))
    (call $set_piece (i32.const 6) (i32.const 5) (get_global $BLACK))

    ;; set current player to black
    (call $set_current_player (get_global $BLACK))
  )

  (export "offsetForPosition" (func $offset_for_position))
  (export "isCrowned" (func $is_crowned))
  (export "isBlack" (func $is_black))
  (export "isWhite" (func $is_white))
  (export "withCrown" (func $with_crown))
  (export "withoutCrown" (func $without_crown))
  (export "getPiece" (func $get_piece))
  (export "setPiece" (func $set_piece))
  (export "isCurrentPlayerPiece" (func $is_current_player_piece))
  (export "getCurrentPlayer" (func $get_current_player))
  (export "setCurrentPlayer" (func $set_current_player))
  (export "toggleCurrentPlayer" (func $toggle_current_player))
  (export "shouldCrownPiece" (func $should_crown_piece))
  (export "crownPiece" (func $crown_piece))
  (export "isValidMove" (func $is_valid_move))
  (export "isValidMoveDistance" (func $is_valid_move_distance))
  (export "movePiece" (func $move_piece))
  (export "performPieceMove" (func $perform_piece_move))
  (export "initBoard" (func $init_board))
  (export "memory" (memory $mem))
)
