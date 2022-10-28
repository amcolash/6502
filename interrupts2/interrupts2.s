PORTB = $6000
PORTA = $6001
DDRB  = $6002
DDRA  = $6003

PCR   = $600c
IFR   = $600d
IER   = $600e

IER_SET = $80
IER_CLR = $00

IER_CA1 = $2
IER_CA2 = $0

value = $0200 ; 2 bytes
mod10 = $0202 ; 2 bytes
message = $0204 ; 6 bytes
counter = $020a ; 2 bytes

E  = %10000000
RW = %01000000
RS = %00100000

  .org $8000

reset:
  ldx #$ff ; Init stack pointer to 0xff
  txs
  cli

  lda #(IER_SET | IER_CA1) ; Set up CA1 interrupt
  sta IER
  lda #$00
  sta PCR

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

  lda #0
  sta counter
  sta counter + 1

loop:
  lda #%00000010 ; Home
  jsr lcd_instruction

  lda #0
  sta message

  ; Initialize value to be the number to convert
  lda counter
  sta value
  lda counter + 1
  sta value + 1

divide:
  ; Initialize the remainder to zero
  lda #0
  sta mod10
  sta mod10 + 1
  clc ; clear carry bit

  ldx #16

divloop:
  ; Rotate quotient and remainder
  rol value
  rol value + 1
  rol mod10
  rol mod10 + 1

  ; a,y = dividend - divisor
  sec ; Set carry bit
  lda mod10
  sbc #10 ; subtract w/ carry
  tay ; transfer a and save low byte in Y
  lda mod10 + 1
  sbc #0 ; subtract w/ carry

  bcc ignore_result ; branch if dividend < divisor (carry flag is clear)

  ; store result if no carry
  sty mod10
  sta mod10 + 1

ignore_result:
  dex
  bne divloop ; branch if x not zero

div_done:
  rol value ; shift in the last bit of the quotient
  rol value + 1

  lda mod10
  clc
  adc #"0"
  jsr push_char

  ; if value != 0, then continue dividing
  lda value
  ora value + 1
  bne divide ; branch if value not zero

  ldx #0

print:
  lda message,x
  beq loop
  jsr print_char
  inx
  jmp print

number: .word 1729

push_char:
  ; Add the character in the A register to the beginning of the null-terminated strin `message`
  pha ; Push new first char onto the stack
  ldy #0

char_loop:
  lda message,y ; Get char on the string and put into X
  tax
  pla
  sta message,y ; Pull char off stack and add it to the string
  iny
  txa
  pha ; Push char from string onto stack

  bne char_loop ; Loop until we get a 0 (null)

  pla
  sta message,y ; Pull the null off the stack and add to the end of the string

  rts

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

nmi:
irq:
  ; save registers to stack
  pha ; save A to the stack

  txa ; transfer X to A
  pha ; save X to the stack

  tya ; transfer Y to A
  pha ; save Y to the stack

  inc counter
  bne exit_irq
  inc counter + 1

exit_irq: ; debounce delays, quick 'n dirty
  ldx #$ff ; delay part 1
  ldy #$ff ; delay part 2

delay:
  dex ; delay part 1
  bne delay

  dey ; delay part 2
  bne delay

  bit PORTA ; Clear interrupt

  ; restore registers from stack
  pla ; pull Y off stack
  tay ; set Y from stack

  pla ; pull X off stack
  tax ; set X from stack

  pla ; pull A off stack

  rti

  .org $fffa
  .word nmi
  .word reset
  .word irq
