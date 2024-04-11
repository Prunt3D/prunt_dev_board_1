-----------------------------------------------------------------------------
--                                                                         --
--                   Part of the Prunt Motion Controller                   --
--                                                                         --
--            Copyright (C) 2024 Liam Powell (liam@prunt3d.com)            --
--                                                                         --
--  This program is free software: you can redistribute it and/or modify   --
--  it under the terms of the GNU General Public License as published by   --
--  the Free Software Foundation, either version 3 of the License, or      --
--  (at your option) any later version.                                    --
--                                                                         --
--  This program is distributed in the hope that it will be useful,        --
--  but WITHOUT ANY WARRANTY; without even the implied warranty of         --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          --
--  GNU General Public License for more details.                           --
--                                                                         --
--  You should have received a copy of the GNU General Public License      --
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.  --
--                                                                         --
-----------------------------------------------------------------------------

with Prunt_Glue;     use Prunt_Glue;
with Prunt_Glue.Glue;
with GPIO;
with Physical_Types; use Physical_Types;
with System.Machine_Code;
with MCU_COMMS;
with adaasn1rtl;
with adaasn1rtl.encoding;
with System.CRTL;
with Ada.Real_Time;
with Ada.Text_IO;
with System.OS_Lib;

procedure Prunt_Dev_Board_1 is

   protected MCU_Inputs is
      function Read return MCU_COMMS.Inputs_Type;
      procedure Edit (Editor : access procedure (Data : in out MCU_COMMS.Inputs_Type));
   private
      Data : MCU_COMMS.Inputs_Type := (others => <>);
   end MCU_Inputs;

   protected body MCU_Inputs is
      function Read return MCU_COMMS.Inputs_Type is
      begin
         return Data;
      end Read;

      procedure Edit (Editor : access procedure (Data : in out MCU_COMMS.Inputs_Type)) is
      begin
         Editor.all (Data);
      end Edit;
   end MCU_Inputs;

   protected MCU_Outputs is
      function Read return MCU_COMMS.Outputs_Type;
      procedure Edit (Editor : access procedure (Data : in out MCU_COMMS.Outputs_Type));
   private
      Data : MCU_COMMS.Outputs_Type :=
        (heater_enable         => False,
         stepper_output_enable => (Data => [others => True]),
         stepper_enable        => (Data => [others => False]),
         fan_pwm               => (Data => [others => 0]));
   end MCU_Outputs;

   protected body MCU_Outputs is
      function Read return MCU_COMMS.Outputs_Type is
      begin
         return Data;
      end Read;

      procedure Edit (Editor : access procedure (Data : in out MCU_COMMS.Outputs_Type)) is
      begin
         Editor.all (Data);
      end Edit;
   end MCU_Outputs;

   task MCU_Comms_Runner is
      entry Start;
   end MCU_Comms_Runner;

   task body MCU_Comms_Runner is
      function Helper_I2C_Initialise return System.CRTL.int with
        Import => True, Convention => C, External_Name => "helperI2cInitialise";

      FD : System.CRTL.int;

      procedure Write (Data : adaasn1rtl.encoding.Bitstream) is
         use type System.CRTL.ssize_t;
         Result : constant System.CRTL.ssize_t :=
           System.CRTL.write (FD, Data.Buffer'Address, System.CRTL.size_t (Data.Size_In_Bytes));
      begin
         if Result /= System.CRTL.ssize_t (Data.Size_In_Bytes) then
            null;
            Ada.Text_IO.Put_Line ("I2C write error: " & Result'Image);
            Ada.Text_IO.Put_Line ("Errno message: " & System.OS_Lib.Errno_Message);
            --  TODO: Report error.
         end if;
         Ada.Text_IO.Put_Line ("I2C write done: " & Result'Image);
      end Write;

      procedure Read (Data : out MCU_COMMS.Packet_Type_ACN_Stream) is
         use type System.CRTL.ssize_t;
         Result : constant System.CRTL.ssize_t :=
           System.CRTL.read (FD, Data.Buffer'Address, System.CRTL.size_t (Data.Size_In_Bytes));
      begin
         Data.Current_Bit_Pos := 0;
         Data.fetchDataPrm    := 0;
         Data.pushDataPrm     := 0;
         if Result /= System.CRTL.ssize_t (Data.Size_In_Bytes) then
            null;
            Ada.Text_IO.Put_Line ("I2C read error: " & Result'Image);
            Ada.Text_IO.Put_Line ("Errno message: " & System.OS_Lib.Errno_Message);
            --  TODO: Report error.
         end if;
         Ada.Text_IO.Put_Line ("I2C read done: " & Result'Image);
      end Read;

      use type MCU_COMMS.Packet_Data_Type_selection;
   begin
      --  Give watchdog time to reset MCU.
      delay 2.0;

      accept Start;

      FD := Helper_I2C_Initialise;

      declare
         Stream : MCU_COMMS.Packet_Type_ACN_Stream;
         Result : adaasn1rtl.ASN1_RESULT;
      begin
         MCU_COMMS.Packet_Type_ACN_Encode
           ((packet_data => (kind => MCU_COMMS.setup_PRESENT, setup => (version => 0))), Stream, Result);
         if not Result.Success then
            null;
            Ada.Text_IO.Put_Line ("Setup encode error: " & Result'Image);
            --  TODO: Report error.
         end if;
         Write (Stream);
      end;

      loop
         delay 0.2;

         declare
            Packet : MCU_COMMS.Packet_Type;
            Stream : MCU_COMMS.Packet_Type_ACN_Stream;
            Result : adaasn1rtl.ASN1_RESULT;

            procedure Editor (Data : in out MCU_COMMS.Inputs_Type) is
            begin
               Data := Packet.packet_data.inputs;
            end Editor;
         begin
            Read (Stream);
            MCU_COMMS.Packet_Type_ACN_Decode (Packet, Stream, Result);
            if (not Result.Success) or (Packet.packet_data.kind /= MCU_COMMS.inputs_PRESENT) then
               null;
               --  TODO: Report error.
               Ada.Text_IO.Put_Line ("Inputs decode error: " & Result'Image);
            else
               MCU_Inputs.Edit (Editor'Access);
            end if;
         end;

         declare
            Stream : MCU_COMMS.Packet_Type_ACN_Stream;
            Result : adaasn1rtl.ASN1_RESULT;
         begin
            MCU_COMMS.Packet_Type_ACN_Encode
              ((packet_data => (kind => MCU_COMMS.outputs_PRESENT, outputs => (MCU_Outputs.Read))), Stream, Result);
            if not Result.Success then
               null;
               --  TODO: Report error.
            else
               Write (Stream);
            end if;
         end;
      end loop;
   end MCU_Comms_Runner;

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

   type Stepper_Name is (J10, J11, J12, J20, J21, J22);

   Step_Pin_Map : constant array (Stepper_Name) of GPIO.Pin_ID :=
     [J10 => 27, J11 => 20, J12 => 21, J20 => 10, J21 => 16, J22 => 25];
   Dir_Pin_Map  : constant array (Stepper_Name) of GPIO.Pin_ID :=
     [J10 => 23, J11 => 19, J12 => 26, J20 => 9, J21 => 11, J22 => 24];

   Stepper_Enable_Pin_Map : constant array (Stepper_Name) of MCU_COMMS.Outputs_Type_stepper_enable_index :=
     [J10 => 1, J11 => 2, J12 => 3, J20 => 4, J21 => 5, J22 => 6];

   procedure Set_Stepper_Pin_State (Stepper : Stepper_Name; Pin : Stepper_Output_Pins; State : Pin_State) is
   begin
      case Pin is
         when Step_Pin =>
            case State is
               when Low_State =>
                  GPIO.Set_Low (Step_Pin_Map (Stepper));
               when High_State =>
                  GPIO.Set_High (Step_Pin_Map (Stepper));
            end case;
         when Dir_Pin =>
            case State is
               when Low_State =>
                  GPIO.Set_Low (Dir_Pin_Map (Stepper));
               when High_State =>
                  GPIO.Set_High (Dir_Pin_Map (Stepper));
            end case;
         when Enable_Pin =>
            declare
               procedure Editor (Data : in out MCU_COMMS.Outputs_Type) is
               begin
                  case State is
                     when Low_State =>
                        Data.stepper_enable.Data (Stepper_Enable_Pin_Map (Stepper)) := False;
                     when High_State =>
                        Data.stepper_enable.Data (Stepper_Enable_Pin_Map (Stepper)) := True;
                  end case;
               end Editor;
            begin
               MCU_Outputs.Edit (Editor'Access);
               delay 1.0;  --  TODO: Wait for message loop instead of just using a big delay.
            end;
      end case;
   end Set_Stepper_Pin_State;

   type Heater_Name is (J2, J3);

   procedure Set_Heater_PWM (Heater : Heater_Name; PWM : PWM_Scale) is
   begin
      null;
      --  TODO
   end Set_Heater_PWM;

   type Thermistor_Name is (J28, J29, J30, J31);

   Thermistor_Index_Map : constant array (Thermistor_Name) of MCU_COMMS.Inputs_Type_adc_temp_value_index :=
     [J28 => 1, J29 => 2, J30 => 3, J31 => 4];

   function Get_Thermistor_Voltage (Thermistor : Thermistor_Name) return Voltage is
   begin
      --  TODO: Check this is correct.
      return
        3.3 * volt * Dimensionless (MCU_Inputs.Read.adc_temp_value.Data (Thermistor_Index_Map (Thermistor))) /
        Dimensionless (MCU_COMMS.Inputs_Type_adc_temp_value_elem'Last);
   end Get_Thermistor_Voltage;

   type Fan_Name is (J14, J15, J16, J17);

   Fan_Index_Map : constant array (Fan_Name) of MCU_COMMS.Outputs_Type_fan_pwm_index :=
     [J14 => 1, J15 => 2, J16 => 3, J17 => 4];

   protected type Fan_Frequency_Type is
      function Get return Frequency;
      procedure Set (F : Frequency);
   private
      Data : Frequency := 0.0 * hertz;
   end Fan_Frequency_Type;

   protected body Fan_Frequency_Type is
      function Get return Frequency is
      begin
         return Data;
      end Get;

      procedure Set (F : Frequency) is
      begin
         Data := F;
      end Set;
   end Fan_Frequency_Type;

   Fan_Frequencies : array (Fan_Name) of Fan_Frequency_Type;

   task Fan_Frequency_Updater;

   task body Fan_Frequency_Updater is
      use type Ada.Real_Time.Time;

      Next_Time   : Ada.Real_Time.Time                         := Ada.Real_Time.Clock;
      Last_Counts : MCU_COMMS.Inputs_Type_fan_tach_count_array := MCU_Inputs.Read.fan_tach_count.Data;
      Next_Counts : MCU_COMMS.Inputs_Type_fan_tach_count_array;
   begin
      loop
         Next_Time := @ + Ada.Real_Time.To_Time_Span (1.0);
         delay until Next_Time;

         Next_Counts := MCU_Inputs.Read.fan_tach_count.Data;

         for I in Fan_Name loop
            declare
               Last : constant Dimensionless := Dimensionless (Last_Counts (Fan_Index_Map (I)));
               Next : Dimensionless          := Dimensionless (Next_Counts (Fan_Index_Map (I)));
            begin
               if Next < Last then
                  Next := Next + Dimensionless (MCU_COMMS.Inputs_Type_fan_tach_count_elem'Last);
               end if;
               Fan_Frequencies (I).Set ((Next - Last) * hertz);
            end;
         end loop;

         Last_Counts := Next_Counts;
      end loop;
   end Fan_Frequency_Updater;

   procedure Set_Fan_PWM (Fan : Fan_Name; PWM : PWM_Scale) is
      MCU_PWM : constant MCU_COMMS.Outputs_Type_fan_pwm_elem :=
        MCU_COMMS.Outputs_Type_fan_pwm_elem (PWM * Dimensionless (MCU_COMMS.Outputs_Type_fan_pwm_elem'Last));

      procedure Editor (Data : in out MCU_COMMS.Outputs_Type) is
      begin
         Data.fan_pwm.Data (Fan_Index_Map (Fan)) := MCU_PWM;
      end Editor;
   begin
      --  TODO: Check this is correct.
      MCU_Outputs.Edit (Editor'Access);
   end Set_Fan_PWM;

   procedure Set_Fan_Voltage (Fan : Fan_Name; Volts : Voltage) is
   begin
      null;
      --  Not supported on dev board.
   end Set_Fan_Voltage;

   function Get_Fan_Frequency (Fan : Fan_Name) return Frequency is
   begin
      return Fan_Frequencies (Fan).Get;
   end Get_Fan_Frequency;

   type Input_Switch_Name is (J5, J6, J7, J8);

   Input_Switch_Pin_Map : constant array (Input_Switch_Name) of GPIO.Pin_ID := [J5 => 4, J6 => 17, J7 => 22, J8 => 18];

   function Get_Input_Switch_State (Switch : Input_Switch_Name) return Pin_State is
   begin
      --  TODO
      return Low_State;
   end Get_Input_Switch_State;

   function Get_Stepper_Pin_State (Stepper : Stepper_Name; Pin : Stepper_Input_Pins) return Pin_State is
   begin
      --  TODO
      return Low_State;
   end Get_Stepper_Pin_State;

   package My_Glue is new Prunt_Glue.Glue
     (Low_Level_Time_Type         => Pi_Time,
      Time_To_Low_Level           => Convert,
      Low_Level_To_Time           => Convert,
      Get_Time                    => Get_Pi_Time,
      Stepper_Name                => Stepper_Name,
      Set_Stepper_Pin_State       => Set_Stepper_Pin_State,
      Get_Stepper_Pin_State       => Get_Stepper_Pin_State,
      Heater_Name                 => Heater_Name,
      Set_Heater_PWM              => Set_Heater_PWM,
      Thermistor_Name             => Thermistor_Name,
      Get_Thermistor_Voltage      => Get_Thermistor_Voltage,
      Fan_Name                    => Fan_Name,
      Set_Fan_PWM                 => Set_Fan_PWM,
      Set_Fan_Voltage             => Set_Fan_Voltage,
      Get_Fan_Frequency           => Get_Fan_Frequency,
      Input_Switch_Name           => Input_Switch_Name,
      Get_Input_Switch_State      => Get_Input_Switch_State,
      Stepgen_Preprocessor_CPU    => 3,
      Stepgen_Pulse_Generator_CPU => 4,
      Config_Path                 => "./prunt_dev_board_1.toml",
      Interpolation_Time          => Convert (0.000_5 * s));

   procedure Helper_Lock_Memory with
     Import => True, Convention => C, External_Name => "helperLockMemory";
begin
   Helper_Lock_Memory;
   MCU_Comms_Runner.Start;

   for P of Step_Pin_Map loop
      GPIO.Set_Output_Mode (P);
   end loop;

   for P of Dir_Pin_Map loop
      GPIO.Set_Output_Mode (P);
   end loop;

   for P of Input_Switch_Pin_Map loop
      GPIO.Set_Input_Mode (P);
   end loop;

   My_Glue.Run;
end Prunt_Dev_Board_1;
