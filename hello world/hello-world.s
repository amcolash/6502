PORTB = $6000
PORTA = $6001
DDRB  = $6002
DDRA  = $6003

E  = %10000000
RW = %01000000
RS = %00100000

  .org $8000

reset:
  ldx #$ff ; Init stack pointer to 0xff
  txs

  lda #%11111111 ; Set all pins on port B to output
  sta DDRB

  lda #%11100000 ; Set first 3 pins on port A to output
  sta DDRA

  lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction

  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction

  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction

  lda #%00000001 ; Clear display
  jsr lcd_instruction

  ldx #0
print:
  lda message,x  ; Load message character, offset by x register
  beq loop       ; Branch to loop when we hit null (0 byte)
  jsr print_char
  inx            ; Increment x register
  jmp print

loop:
  jmp loop

message: .asciiz "Hello, world!"

lcd_wait:
  pha            ; Push A register to stack
  lda #%00000000 ; Set all pins on port B to input
  sta DDRB
lcd_busy:
  lda #RW        ; Set RW flag and read value into A register
  sta PORTA
  lda #(RW | E)
  sta PORTA
  lda PORTB

  and #%10000000 ; Check if still busy, zero flag set if not busy
  bne lcd_busy   ; Branch and loop back if lcd is busy

  lda #RW        ; Clear Enable Bit
  sta PORTA
  lda #%11111111 ; Set all pins on port B to output
  sta DDRB

  pla            ; Pull A register off stack and restore it
  rts

lcd_instruction:
  jsr lcd_wait   ; Wait until LCD is not busy
  sta PORTB
  lda #0         ; Clear RS/RW/E bits
  sta PORTA
  lda #E         ; Set enable bit to send instruction
  sta PORTA
  lda #0         ; Clear RS/RW/E bits
  sta PORTA
  rts

print_char:
  jsr lcd_wait   ; Wait until LCD is not busy
  sta PORTB
  lda #RS        ; Set RS; Clear RW/E bits
  sta PORTA
  lda #(RS | E)  ; Set enable bit to send instruction
  sta PORTA
  lda #RS        ; Clear E bits
  sta PORTA
  rts

  .org $fffc
  .word reset
  .word $0000
