package GPIO is

   type Pin_ID is range 0..9;

   --  Not thread safe.
   procedure Set_Output_Mode (Pin : Pin_ID);

   --  Not thread safe.
   procedure Toggle_Output (Pin : Pin_ID);

end GPIO;
