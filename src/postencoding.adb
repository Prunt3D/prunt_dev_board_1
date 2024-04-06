with adaasn1rtl.encoding.acn;
with Interfaces; use Interfaces;
with GNAT.CRC32;

package body postencoding with
  SPARK_Mode
is

   function calc_crc_32 (Buf : OctetBuffer; Len : Natural) return Unsigned_32 is
      CRC : GNAT.CRC32.CRC32;
   begin
      GNAT.CRC32.Initialize (CRC);
      for I in 1 .. Len loop
         GNAT.CRC32.Update (CRC, Character'Val (Buf (I)));
      end loop;
      return GNAT.CRC32.Get_Value (CRC);
   end calc_crc_32;

   procedure my_encoding_patcher
     (unused_val                       :        MCU_COMMS.Packet_Type;
      unused_bitStreamPositions_start1 :        adaasn1rtl.encoding.BitstreamPtr;
      bitStreamPositions_1             :        MCU_COMMS.Packet_Type_extension_function_positions;
      bs                               : in out adaasn1rtl.encoding.Bitstream)
   is
      startPosInBits : constant adaasn1rtl.Asn1UInt :=
        adaasn1rtl.Asn1UInt (bitStreamPositions_1.Packet_Type_body_length_in_bytes.Current_Bit_Pos);
      endPosIBits    : constant adaasn1rtl.Asn1UInt :=
        adaasn1rtl.Asn1UInt (bitStreamPositions_1.Packet_Type_packet_crc32.Current_Bit_Pos);
      lengthInBytes  : constant adaasn1rtl.Asn1UInt := (endPosIBits - startPosInBits - 16) / 8;
      crc32          : adaasn1rtl.Asn1UInt;
      orignalBit_Pos : constant Natural             := bs.Current_Bit_Pos;
   begin

      --  use the ACN function to encode the length value. Please note that
      --   we use the Packet_Type_packet_length_in_bytes field in the
      --  Packet_Type_extension_function_positions to encode the length in the
      --  correct position.
      bs.Current_Bit_Pos := bitStreamPositions_1.Packet_Type_body_length_in_bytes.Current_Bit_Pos;
      adaasn1rtl.encoding.acn.Acn_Enc_Int_PositiveInteger_ConstSize (bs, lengthInBytes, 16);

      --  calculate crc
      crc32              :=
        adaasn1rtl.Asn1UInt
          (calc_crc_32 (bs.Buffer, bitStreamPositions_1.Packet_Type_packet_crc32.Current_Bit_Pos / 8));
      --  encode crc32 in the correct position
      bs.Current_Bit_Pos := bitStreamPositions_1.Packet_Type_packet_crc32.Current_Bit_Pos;
      adaasn1rtl.encoding.acn.Acn_Enc_Int_PositiveInteger_ConstSize (bs, crc32, 32);
      bs.Current_Bit_Pos := orignalBit_Pos;

   end my_encoding_patcher;

   function my_crc_validator
     (unused_val                       :        MCU_COMMS.Packet_Type;
      unused_bitStreamPositions_start1 :        adaasn1rtl.encoding.BitstreamPtr;
      bitStreamPositions_1             :        MCU_COMMS.Packet_Type_extension_function_positions;
      bs                               : in out adaasn1rtl.encoding.Bitstream)
      return adaasn1rtl.ASN1_RESULT
   is
      startPosInBits : constant adaasn1rtl.Asn1UInt :=
        adaasn1rtl.Asn1UInt (bitStreamPositions_1.Packet_Type_body_length_in_bytes.Current_Bit_Pos);
      endPosIBits    : constant adaasn1rtl.Asn1UInt :=
        adaasn1rtl.Asn1UInt (bitStreamPositions_1.Packet_Type_packet_crc32.Current_Bit_Pos);
      lengthInBytes  : constant adaasn1rtl.Asn1UInt := (endPosIBits - startPosInBits - 16) / 8;
      decLenInBytes  : adaasn1rtl.Asn1UInt          := 0;
      crc32          : adaasn1rtl.Asn1UInt;
      decodeCrc32    : adaasn1rtl.Asn1UInt;
      --  orignalBit_Pos : constant Natural    := bs.Current_Bit_Pos;
      ret1           : adaasn1rtl.ASN1_RESULT;
      ret2           : adaasn1rtl.ASN1_RESULT;
      ret            : adaasn1rtl.ASN1_RESULT;
   begin
      --  use the ACN function to decode the length value.
      --  Please note that we use the Packet_Type_packet_length_in_bytes field
      --  in the Packet_Type_extension_function_positions to encode the length
      --  in the correct position.
      bs.Current_Bit_Pos := bitStreamPositions_1.Packet_Type_body_length_in_bytes.Current_Bit_Pos;
      adaasn1rtl.encoding.acn.Acn_Dec_Int_PositiveInteger_ConstSize (bs, decLenInBytes, 0, 65_535, 16, ret1);

      --  calculate crc
      crc32              :=
        adaasn1rtl.Asn1UInt
          (calc_crc_32 (bs.Buffer, bitStreamPositions_1.Packet_Type_packet_crc32.Current_Bit_Pos / 8));
      --  decode crc32 from the bitstream
      bs.Current_Bit_Pos := bitStreamPositions_1.Packet_Type_packet_crc32.Current_Bit_Pos;
      adaasn1rtl.encoding.acn.Acn_Dec_Int_PositiveInteger_ConstSize (bs, decodeCrc32, 0, 4_294_967_295, 32, ret2);

      ret :=
        adaasn1rtl.ASN1_RESULT'
          (Success   => ret1.Success and ret2.Success and lengthInBytes = decLenInBytes and crc32 = decodeCrc32,
           ErrorCode => 0);
      if not ret.Success then
         ret.ErrorCode := 3_141_592;  --  assign custom error code
      end if;

      return ret;
   end my_crc_validator;

end postencoding;
