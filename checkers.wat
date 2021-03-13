(module
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
  (global $BLACK i32 (i32.const 1))
  (global $WHITE i32 (i32.const 2))
  (global $BLACK_OR_WHITE i32 (i32.const 3))
  (global $CROWN i32 (i32.const 4))

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

  (export "offsetForPosition" (func $offset_for_position))
  (export "isCrowned" (func $is_crowned))
  (export "isBlack" (func $is_black))
  (export "isWhite" (func $is_white))
  (export "withCrown" (func $with_crown))
  (export "withoutCrown" (func $without_crown))
)
