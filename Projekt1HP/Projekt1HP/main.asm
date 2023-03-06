;/********************************************************************************
;*           - Assemblerdirektiv:
;*              .EQU (Equal) : Allmäna makrodefinitioner.
;*              .DEF (Define): Makrodefinitioner för CPU-register.
;*              .ORG (Origin): Används för att specificera en adress.
;*
;*           - Assemblerinstruktioner:
;*              RJMP (Relativ Jump)         : Hoppar till angiven adress.
;*              RETI (Return From Interrupt): Hoppar tillbaka från avbrottsrutin.
;*              LDI (Load Immediate)        : Läser in värde till CPU-register.
;*              OUT (Store to I/O location) : Skriver till I/O-register.
;*              SEI (Set Interrupt Flag)    : Ettställer interrupt-flaggan.
;*              STS (Store To Dataspace)    : Skriver till dataminnet.
;*              LDS (Load From Dataspace)   : Läser från dataminnet.
;*              INC (Increment)             : Inkrementerar värde i CPU-register.
;*              CPI (Compare Immediate)     : Jämför innehåll i CPU-register
;*                                            med ett värde.
;*              BRLO (Branch If Lower)      : Hoppar till angiven adress om
;*                                            resultatet från föregående
;*                                            jämförelse blev negativt, vilket
;*                                            indikeras genom att N-flaggan
;*                                            (Negative) i statusregistret
;*                                            SREG är lika med noll.
;********************************************************************************/

; Makrodefinitioner:
.EQU LED1 = PORTB0 ; Lysdiod 1 ansluten till pin 8 (PORTB0).
.EQU LED2 = PORTB1 ; Lysdiod 2 ansluten till pin 9 (PORTB1).

.EQU BUTTON1 = PORTB5 ; Button 1 ansluten till pin 13 (PORTB5)
.EQU BUTTON2 = PORTB4 ; Button 2 ansluten till pin 12 (PORTB4)
.EQU BUTTON3 = PORTB3 ; Button 3 ansluten till pin 11 (PORTB3)

.EQU TIMER0_MAX_COUNT = 18  ; 18 timeravbrott för 300 ms fördröjning.
.EQU TIMER1_MAX_COUNT = 6 ; 6 timeravbrott för 100 ms fördröjning.
.EQU TIMER2_MAX_COUNT = 12 ; 12 timeravbrott för 200 ms fördröjning.

.EQU RESET_vect        = 0x00 ; Reset-vektor, utgör programmets startpunkt.
.EQU PCINT0_vect	   = 0x06 ; Avbrottsvektor för PCI-avbrott på I/O-port B.
.EQU TIMER2_OVF_vect   = 0x12 ; Avbrottsvektor för Timer 2 i Normal Mode.
.EQU TIMER1_COMPA_vect = 0x16 ; Avbrottsvektor för Timer 1 i CTC Mode.
.EQU TIMER0_OVF_vect   = 0x20 ; Avbrottsvektor för Timer 0 i Normal Mode.

.DEF LED1_REG    = R16 ; CPU-register som lagrar (1 << LED1).
.DEF LED2_REG    = R17 ; CPU-register som lagrar (1 << LED2).
.DEF COUNTER_REG = R24 ; CPU-register för uppräkning och jämförelse av räknarvariablerna.

;/********************************************************************************
;* .DSEG (Data Segment): Dataminnet - Här lagras statiska variabler.
;********************************************************************************/
.DSEG
.ORG SRAM_START ; Deklaration av statiska variabler i början av dataminnet.
   timer0_counter: .byte 1 ; static uint8_t timer0_counter = 0;
   timer1_counter: .byte 1 ; static uint8_t timer1_counter = 0;
   timer2_counter: .byte 1 ; static uint8_t timer2_counter = 0;

;/********************************************************************************
;* .CSEG (Code Segment): Programminnet - Här lagras programkod och konstanter.
;********************************************************************************/
.CSEG ; Kodsegmentet (programminnet) - Här lagras programkoden.

;/********************************************************************************
;* RESET_vect: Programmet startpunkt, som även hoppas till vid systemåterställning.
;*             Programhopp sker till subrutinen main för att starta programmet.
;********************************************************************************/
.ORG RESET_vect
   RJMP main

;/********************************************************************************
;* PCINT0_vect: Avbrottsvektor för PCI-avbrott på I/O-port B, som äger rum vid
;*              nedtryckning eller uppsläppning av någon av tryckknapparna.
;*              Hopp sker till motsvarande avbrottsrutin ISR_PCINT0 för att
;*              hantera avbrottet.
;********************************************************************************/
.ORG PCINT0_vect
   RJMP ISR_PCINT0

;/********************************************************************************
;* TIMER2_OVF_vect: Avbrottsvektor för Timer 2 i Normal Mode, som hoppas till
;*                  var 16.384:e ms. Programhopp sker till motsvarande
;*                  avbrottsrutin ISR_TIMER2_OVF för att hantera avbrottet.
;********************************************************************************/
.ORG TIMER2_OVF_vect
   RJMP ISR_TIMER2_OVF

;/********************************************************************************
;* TIMER1_COMPA_vect: Avbrottsvektor för Timer 1 i CTC Mode, som hoppas till
;*                    var 16.384:e ms. Programhopp sker till motsvarande
;*                    avbrottsrutin ISR_TIMER1_COMPA för att hantera avbrottet.
;********************************************************************************/
.ORG TIMER1_COMPA_vect
   RJMP ISR_TIMER1_COMPA

;/********************************************************************************
;* TIMER0_OVF_vect: Avbrottsvektor för Timer 0 i Normal Mode, som hoppas till
;*                  var 16.384:e ms. Programhopp sker till motsvarande
;*                  avbrottsrutin ISR_TIMER0_OVF för att hantera avbrottet.
;********************************************************************************/
.ORG TIMER0_OVF_vect
   RJMP ISR_TIMER0_OVF

;/********************************************************************************
;* ISR_PCINT0: Avbrottsrutin för hantering av PCI-avbrott på I/O-port B, som
;*             äger rum vid nedtryckning eller uppsläppning av någon av 
;*             tryckknapparna. Om nedtryckning av en tryckknapp orsakade 
;*             avbrottet togglas motsvarande lysdiod, annars görs ingenting.
;********************************************************************************/
ISR_PCINT0:
	IN R24, PINB
	ANDI R24, (1 << BUTTON1)
	BREQ ISR_PCINT0_end
timer_toggle:
	LDS R24, TIMSK0			  ; Läser in värdet från maskregister för att kolla om timer0 är på.
	ANDI R24, (1 << TOIE0)	  ; Ignorerar alla bitar förutom TOIE0
	BRNE timer0_off			  ; Om timer0 är på (TOIE0 ettställd) stängs den av
timer0_on:
	STS TIMSK0, R16           ; Sätter på ovf-avbrott på timer 0
	RETI
timer0_off:
	CLR R24					  ; R24 = 0
	STS TIMSK0, R24			  ; Stänger av timer 0
	IN R24, PORTB			  ; Hämtar befintligt innehåll från PORTB för modifikation
	ANDI R24, ~(1 << LED1)	  ; Nollställer LED bit, övriga opåverkade
	OUT PORTB, R24			  ; Skriver tillbaka nya värdet till PORTB, LED nu släckt
ISR_PCINT0_end:
    RETI                     ; Avslutar avbrottet och återställer systemet.

;/********************************************************************************
;* ISR_TIMER0_OVF: Avbrottsrutin för Timer 0 i Normal Mode, som äger rum var 
;*                 16.384:e ms vid overflow (uppräkning till 256, då räknaren 
;*                 blir överfull). Ungefär var 100:e ms (var 6:e avbrott) 
;*                 togglas lysdiod LED1.
;********************************************************************************/
ISR_TIMER0_OVF:
   LDS COUNTER_REG, timer0_counter   ; Läser in värdet på timer0_counter från dataminnet.
   INC COUNTER_REG                   ; Räknar upp antalet exekverade avbrott.
   CPI COUNTER_REG, TIMER0_MAX_COUNT ; Jämför antalet avbrott med heltalet 18.
   BRLO ISR_TIMER0_OVF_end           ; Om mindre än 18 avbrott har skett avslutas avbrottsrutinen.

   LDI COUNTER_REG, 0x00             ; Nollställer räknaren inför nästa uppräkning.
ISR_TIMER0_OVF_end:
   STS timer0_counter, COUNTER_REG   ; Skriver det uppdaterade värdet på timer0_counter till dataminnet.
   RETI                              ; Avslutar avbrottsrutinen, återställer diverse register med mera.
   
;/********************************************************************************
;* ISR_TIMER1_COMPA: Avbrottsrutin för Timer 1 i CTC Mode, som äger rum var 
;*                   16.384:e ms vid vid uppräkning till 256. Ungefär var 
;*                   100:e ms (var 6:e avbrott) togglas lysdiod LED1.
;********************************************************************************/
ISR_TIMER1_COMPA:
   LDS COUNTER_REG, timer1_counter   ; Läser in värdet på timer1_counter från dataminnet.
   INC COUNTER_REG                   ; Räknar upp antalet exekverade avbrott.
   CPI COUNTER_REG, TIMER1_MAX_COUNT ; Jämför antalet avbrott med heltalet 6.
   BRLO ISR_TIMER1_COMPA_end         ; Om mindre än 6 avbrott har skett avslutas avbrottsrutinen.
   OUT PINB, LED1_REG                ; Annars togglas lysdiod 1.
   LDI COUNTER_REG, 0x00             ; Nollställer räknaren inför nästa uppräkning.
ISR_TIMER1_COMPA_end :
   STS timer1_counter, COUNTER_REG   ; Skriver det uppdaterade värdet på timer1_counter till dataminnet.
   RETI                              ; Avslutar avbrottsrutinen, återställer diverse register med mera.

;/********************************************************************************
;* ISR_TIMER2_OVF: Avbrottsrutin för Timer 2 i Normal Mode, som äger rum var 
;*                 16.384:e ms vid overflow (uppräkning till 256, då räknaren 
;*                 blir överfull). Ungefär var 200:e ms (var 12:e avbrott) 
;*                 togglas lysdiod LED2.
;********************************************************************************/
ISR_TIMER2_OVF:
   LDS COUNTER_REG, timer2_counter   ; Läser in värdet på timer2_counter från dataminnet.
   INC COUNTER_REG                   ; Räknar upp antalet exekverade avbrott.
   CPI COUNTER_REG, TIMER2_MAX_COUNT ; Jämför antalet avbrott med heltalet 12.
   BRLO ISR_TIMER2_OVF_end           ; Om mindre än 12 avbrott har skett avslutas avbrottsrutinen.
   OUT PINB, LED2_REG                ; Annars togglas lysdiod 2.
   LDI COUNTER_REG, 0x00             ; Nollställer räknaren inför nästa uppräkning.
ISR_TIMER2_OVF_end:
   STS timer2_counter, COUNTER_REG   ; Skriver det uppdaterade värdet på timer2_counter till dataminnet.
   RETI                              ; Avslutar avbrottsrutinen, återställer diverse register med mera.

;/********************************************************************************
;* main: Initierar systemet vid start. Programmet hålls sedan igång så länge
;*       matningsspänning tillförs.
;********************************************************************************/
main:
;/********************************************************************************
;* setup: Sätter lysdiodernas pinnar till utportar samt aktiverar timerkretsarna
;*        så att avbrott sker var 16.384:e millisekund för respektive timer.
;*        Notering: 256 = 1 0000 0000, som skrivs till OCR1AH respektive OCR1AL.
;********************************************************************************/
setup:
   LDI R16, (1 << LED1) | (1 << LED2)			     ; Lagrar 0000 0011 i R16.
   OUT DDRB, R16                                     ; Sätter lysdioderna till utportar.
   LDI R24, (1 << BUTTON1) | (1 << BUTTON2) | (1 << BUTTON3)
   OUT PORTB, R24
   SEI                                               ; Aktiverar avbrott globalt.
init_interrupts:
   STS PCICR, R16 
   STS PCMSK0, R24
init_timer0:
   LDI R16, (1 << CS02) | (1 << CS00)                ; Sätter prescaler till 1024.
   OUT TCCR0B, R16                                   ; Aktiverar Timer 0 i Normal Mode.
   LDI R18, (1 << TOIE0)                             ; Ettställer bit för avbrott i Normal Mode.
   STS TIMSK0, R18                                   ; Aktiverar OVF-avbrott för Timer 0.
init_timer1:
   LDI R16, (1 << CS12) | (1 << CS10) | (1 << WGM12) ; Sätter prescaler till 1024.
   STS TCCR1B, R16                                   ; Aktiverar Timer 1 i CTC Mode.
   LDI R17, 0x01                                     ; Lagrar 0000 0001 i R17.
   LDI R16, 0x00                                     ; Lagrar 0000 0000 i R16.
   STS OCR1AH, R17                                   ; Tilldelar åtta mest signifikanta bitar av 256.
   STS OCR1AL, R16                                   ; Tilldelar åtta minst signifikanta bitar av 256.
   LDI R16, (1 << OCIE1A)                            ; Ettställer bit för avbrott i CTC Mode.
   STS TIMSK1, R16                                   ; Aktiverar CTC-avbrott för Timer 1.
init_timer2:
   LDI R16, (1 << CS22) | (1 << CS21) | (1 << CS20)  ; Sätter prescaler till 1024.
   STS TCCR2B, R16                                   ; Aktiverar Timer 2 i Normal Mode.
   STS TIMSK2, R18                                   ; Aktiverar OVF-avbrott för Timer 2.
init_registers:
   LDI LED1_REG, (1 << LED1)                         ; Används för att toggla lysdiod 1.
   LDI LED2_REG, (1 << LED2)                         ; Används för att toggla lysdiod 2.
   
/********************************************************************************
* main_loop: Kontinuerlig loop som håller igång programmet.
********************************************************************************/
main_loop:   
   RJMP main_loop ; Återstartar kontinuerligt loopen.