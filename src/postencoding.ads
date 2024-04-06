with adaasn1rtl; use adaasn1rtl;
with adaasn1rtl.encoding;
with MCU_COMMS;

package postencoding with
  SPARK_Mode
is

   procedure my_encoding_patcher
     (unused_val                       :        MCU_COMMS.Packet_Type;
      unused_bitStreamPositions_start1 :        adaasn1rtl.encoding.BitstreamPtr;
      bitStreamPositions_1             :        MCU_COMMS.Packet_Type_extension_function_positions;
      bs                               : in out adaasn1rtl.encoding.Bitstream);

   function my_crc_validator
     (unused_val                       :        MCU_COMMS.Packet_Type;
      unused_bitStreamPositions_start1 :        adaasn1rtl.encoding.BitstreamPtr;
      bitStreamPositions_1             :        MCU_COMMS.Packet_Type_extension_function_positions;
      bs                               : in out adaasn1rtl.encoding.Bitstream)
      return adaasn1rtl.ASN1_RESULT;

end postencoding;
