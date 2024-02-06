with Gcode_Parser;   use Gcode_Parser;
with Motion_Planner; use Motion_Planner;
with Physical_Types; use Physical_Types;
with Ada.Text_IO;    use Ada.Text_IO;
with Motion_Planner.Planner;
with Ada.Command_Line;
with GNAT.OS_Lib;
with Ada.Exceptions;
with System.Dim.Float_IO;
with GPIO;
use type GPIO.Pin_ID;
with Stepgen.Stepgen;
with System.Machine_Code;
with System.Multiprocessors.Dispatching_Domains; use System.Multiprocessors.Dispatching_Domains;

package body Main is

   package Dimensioed_Float_IO is new System.Dim.Float_IO (Dimensioned_Float);
   use Dimensioed_Float_IO;

   package Planner is new Motion_Planner.Planner (Boolean, False, [others => 0.0 * mm]);
   use Planner;

   type Pi_Time is mod 2**64;

   function Convert (T : Time) return Pi_Time is
   begin
      return Pi_Time (T * (54_000_000.0 / s));
   end Convert;

   function Convert (T : Pi_Time) return Time is
   begin
      return Dimensionless (T) / (54_000_000.0 / s);
   end Convert;

   function Get_Pi_Time return Pi_Time is
   begin
      return T : Pi_Time do
         System.Machine_Code.Asm
           ("isb; mrs %0, cntvct_el0",
            Outputs  => [Pi_Time'Asm_Output ("=r", T)],
            Clobber  => "memory",
            Volatile => True);
      end return;
   end Get_Pi_Time;

   function Return_False (Data : Boolean) return Boolean is
   begin
      return False;
   end Return_False;

   type Step_Count is range 0 .. 2**63 - 1;

   type Stepper_Position is array (Axis_Name) of Step_Count;

   function Position_To_Stepper_Position (Pos : Scaled_Position) return Stepper_Position is
   begin
      return Step_Pos : Stepper_Position do
         Step_Pos (X_Axis) := Step_Count (Pos (X_Axis) * 1_000.0);
         Step_Pos (Y_Axis) := Step_Count (Pos (Y_Axis) * 2_000.0);
         Step_Pos (Z_Axis) := Step_Count (Pos (Z_Axis) * 4_000.0);
         Step_Pos (E_Axis) := Step_Count (Pos (E_Axis) * 8_000.0);
      end return;
   end Position_To_Stepper_Position;

   procedure Do_Nothing (Data : Boolean) is
   begin
      null;
   end Do_Nothing;

   procedure Do_Nothing (Stepper : Axis_Name; Dir : Stepgen.Direction) is
   begin
      null;
   end Do_Nothing;

   procedure Do_Step (Stepper : Axis_Name) is
   begin
      GPIO.Toggle_Output (GPIO.Pin_ID (Axis_Name'Pos (Stepper)) + 1);
   end Do_Step;

   package My_Stepgen is new Stepgen.Stepgen
     (Low_Level_Time_Type          => Pi_Time,
      Low_Level_To_Time            => Convert,
      Time_To_Low_Level            => Convert,
      Get_Time                     => Get_Pi_Time,
      Planner                      => Planner,
      Is_Homing_Move               => Return_False,
      Is_Home_Switch_Hit           => Return_False,
      Step_Count                   => Step_Count,
      Stepper_Name                 => Axis_Name,
      Stepper_Position             => Stepper_Position,
      Position_To_Stepper_Position => Position_To_Stepper_Position,
      Do_Step                      => Do_Step,
      Set_Direction                => Do_Nothing,
      Finished_Block               => Do_Nothing,
      Interpolation_Time           => Convert (0.000_2 * s));

   Limits : constant Motion_Planner.Kinematic_Limits :=
     (Velocity_Max     => 100.0 * mm / s,
      Acceleration_Max => 1_500.0 * mm / s**2,
      Jerk_Max         => 2_500_000.0 * mm / s**3,
      Snap_Max         => 0.8 * 500_000_000.0 * mm / s**4, --  Jm / Ts
      Crackle_Max      => 0.8 * 500_000_000_000.0 * mm / s**5, --  Jm / Ts**2
      Chord_Error_Max  => 0.1 * mm);

   task Reader is
      entry Start (Filename : String);
   end Reader;

   task body Reader is
      F              : File_Type;
      C              : Gcode_Parser.Command := (others => <>);
      Parser_Context : Gcode_Parser.Context := Make_Context ([others => 0.0 * mm], 100.0 * mm / s);
   begin
      accept Start (Filename : String) do
         Open (F, In_File, Filename);
      end Start;

      while not End_Of_File (F) loop
         declare
            Line : String := Get_Line (F);
         begin
            Parse_Line (Parser_Context, Line, C);
            if C.Kind = Move_Kind then
               C.Pos (E_Axis) := 0.0 * mm;
               Planner.Enqueue ((Kind => Planner.Move_Kind, Pos => C.Pos * [others => 1.0], Limits => Limits));
            end if;
         exception
            when E : Bad_Line =>
               Put_Line ("Error on line:");
               Put_Line (Line);
               Put_Line (Ada.Exceptions.Exception_Information (E));
               raise Bad_Line;
         end;
      end loop;

      Planner.Enqueue ((Kind => Planner.Flush_Kind, Flush_Extra_Data => True));
   exception
      when E : others =>
         Put_Line ("Error in file reader: ");
         Put_Line (Ada.Exceptions.Exception_Information (E));
   end Reader;

   Block : Planner.Execution_Block;

   procedure Helper_Lock_Memory with
     Import => True, Convention => C, External_Name => "helperLockMemory";

   procedure Main is
      Total_Time            : Time   := 0.0 * s;
      Total_Corner_Distance : Length := 0.0 * mm;
   begin
      if Ada.Command_Line.Argument_Count /= 1 then
         Put_Line ("Provide exactly 1 command line argument.");
         GNAT.OS_Lib.OS_Exit (1);
      end if;

      Helper_Lock_Memory;

      GPIO.Set_Output_Mode (0);
      GPIO.Set_Output_Mode (1);
      GPIO.Set_Output_Mode (2);
      GPIO.Set_Output_Mode (3);

      Set_CPU (2, Planner.Runner'Identity);
      Set_CPU (3, My_Stepgen.Preprocessor'Identity);
      Set_CPU (4, My_Stepgen.Runner'Identity);

      Reader.Start (Ada.Command_Line.Argument (1));
   end Main;
end Main;
