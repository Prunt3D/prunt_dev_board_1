package GPIO is

   type Pin_ID is range 0..29;

   --  Not thread safe.
   procedure Set_Output_Mode (Pin : Pin_ID);

   procedure Set_High (Pin : Pin_ID);
   procedure Set_Low (Pin : Pin_ID);
end GPIO;
