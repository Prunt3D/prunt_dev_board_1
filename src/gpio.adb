with System;

package body GPIO is

   Pin_Is_Set : array (Pin_ID) of Boolean := [others => False];

   function Helper_GPIO_Initialise return System.Address with
     Import => True, Convention => C, External_Name => "helperGpioInitialise";

   type FSEL is (Input, Output);
   for FSEL use (Input => 2#000#, Output => 2#001#);
   for FSEL'Size use 3;

   type GPFSEL_Index is range 0 .. 9;
   type GPFSEL is array (GPFSEL_Index range <>) of FSEL with
     Pack;
   for GPFSEL'Component_Size use 3;

   type GPSET_Values is (No_Effect, Set);
   for GPSET_Values use (No_Effect => 0, Set => 1);
   for GPSET_Values'Size use 1;

   type GPSET_Index is range 0 .. 31;
   type GPSET is array (GPSET_Index range <>) of GPSET_Values with
     Pack;
   for GPSET'Component_Size use 1;

   type GPCLR_Values is (No_Effect, Clear) with
     Volatile;
   for GPCLR_Values use (No_Effect => 0, Clear => 1);
   for GPCLR_Values'Size use 1;

   type GPCLR_Index is range 0 .. 31;
   type GPCLR is array (GPCLR_Index range <>) of GPCLR_Values with
     Pack;
   for GPCLR'Component_Size use 1;

   type GPIO_Registers_Type is record
      GPFSEL0 : GPFSEL (0 .. 9);
      GPFSEL1 : GPFSEL (0 .. 9);
      GPFSEL2 : GPFSEL (0 .. 9);
      GPFSEL3 : GPFSEL (0 .. 9);
      GPFSEL4 : GPFSEL (0 .. 9);
      GPFSEL5 : GPFSEL (0 .. 7);
      GPSET0  : GPSET (0 .. 31);
      GPSET1  : GPSET (0 .. 25);
      GPCLR0  : GPCLR (0 .. 31);
      GPCLR1  : GPCLR (0 .. 25);
   end record;

   for GPIO_Registers_Type'Size use 16#F4# * 8;
   for GPIO_Registers_Type use record
      GPFSEL0 at 16#00# range 0 .. 29;
      GPFSEL1 at 16#04# range 0 .. 29;
      GPFSEL2 at 16#08# range 0 .. 29;
      GPFSEL3 at 16#0C# range 0 .. 29;
      GPFSEL4 at 16#10# range 0 .. 29;
      GPFSEL5 at 16#14# range 0 .. 23;
      GPSET0  at 16#1C# range 0 .. 31;
      GPSET1  at 16#20# range 0 .. 25;
      GPCLR0  at 16#28# range 0 .. 31;
      GPCLR1  at 16#2C# range 0 .. 25;
   end record;

   GPIO_Registers : GPIO_Registers_Type with
     Address => Helper_GPIO_Initialise, Volatile;

   procedure Set_Output_Mode (Pin : Pin_ID) is
   begin
      GPIO_Registers.GPFSEL0 (GPFSEL_Index (Pin)) := Output;
   end Set_Output_Mode;

   procedure Toggle_Output (Pin : Pin_ID) is
   begin
      if Pin_Is_Set (Pin) then
         Pin_Is_Set (Pin) := False;
         declare
            Reg : GPCLR (0 .. 31) := [others => No_Effect];
         begin
            Reg (GPCLR_Index (Pin)) := Clear;
            GPIO_Registers.GPCLR0   := Reg;
         end;
      else
         Pin_Is_Set (Pin) := True;
         declare
            Reg : GPSET (0 .. 31) := [others => No_Effect];
         begin
            Reg (GPSET_Index (Pin)) := Set;
            GPIO_Registers.GPSET0   := Reg;
         end;
      end if;
   end Toggle_Output;

end GPIO;
