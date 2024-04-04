with Prunt_Glue;     use Prunt_Glue;
with Prunt_Glue.Glue;
with GPIO;
with Physical_Types; use Physical_Types;
with System.Machine_Code;

procedure Prunt_Dev_Board_1 is

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
            --  TODO
            null;
      end case;
   end Set_Stepper_Pin_State;

   type Heater_Name is (J2, J3);

   procedure Set_Heater_PWM (Heater : Heater_Name; PWM : PWM_Scale) is
   begin
      null;
      --  TODO
   end Set_Heater_PWM;

   type Thermistor_Name is (J26_And_27, J28, J29, J30, J31);

   function Get_Thermistor_Voltage (Thermistor : Thermistor_Name) return Voltage is
   begin
      return 0.0 * volt;
      --  TODO
   end Get_Thermistor_Voltage;

   type Fan_Name is (J14, J15, J16, J17);

   procedure Set_Fan_PWM (Fan : Fan_Name; PWM : PWM_Scale) is
   begin
      null;
      --  TODO
   end Set_Fan_PWM;

   procedure Set_Fan_Voltage (Fan : Fan_Name; Volts : Voltage) is
   begin
      null;
      --  Not supported on dev board.
   end Set_Fan_Voltage;

   function Get_Fan_Frequency (Fan : Fan_Name) return Frequency is
   begin
      return 0.0 * hertz;
      --  TODO
   end Get_Fan_Frequency;

   type Input_Switch_Name is (J5, J6, J7, J8);

   Input_Switch_Pin_Map : array (Input_Switch_Name) of GPIO.Pin_ID := [J5 => 4, J6 => 17, J7 => 22, J8 => 18];

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

begin
   My_Glue.Run;
end Prunt_Dev_Board_1;
