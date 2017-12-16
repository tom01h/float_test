module fmul
  (
   input             clk,
   input             reset,
   input             req,
   input [31:0]      x,
   input [31:0]      y,
   output reg [31:0] rslt,
   output reg [4:0]  flag
   );

   integer           i;
   reg [31:0]        xh;

   wire [2:0]    br0 = {xh[1:0],1'b0};
   wire [2:0]    br1 = xh[3:1];
   wire [2:0]    br2 = xh[5:3];
   wire [2:0]    br3 = xh[15:13];
   wire [2:0]    br4 = xh[17:15];
   wire [2:0]    br5 = xh[19:17];

   wire [35:0]   by0, by1, by2;
   wire [35:0]   by3, by4, by5;

   wire          ng0 = (br0[2:1]==2'b10)|(br0[2:0]==3'b110);
   wire          ng1 = (br1[2:1]==2'b10)|(br1[2:0]==3'b110);
//   wire          ng2 = (br2[2:1]==2'b10)|(br2[2:0]==3'b110);
   reg           ng2;
   wire          ng3 = (br3[2:1]==2'b10)|(br3[2:0]==3'b110);
   wire          ng4 = (br4[2:1]==2'b10)|(br4[2:0]==3'b110);
//   wire          ng5 = (br5[2:1]==2'b10)|(br5[2:0]==3'b110);
   reg           ng5;

   wire [23:0]   fracy;
   booth booth0(.i(1'b0), .y_signed(1'b0), .br(br0), .y({fracy,8'h00}), .by(by0));
   booth booth1(.i(1'b1), .y_signed(1'b0), .br(br1), .y({fracy,8'h00}), .by(by1));
   booth booth2(.i(1'b1), .y_signed(1'b0), .br(br2), .y({fracy,8'h00}), .by(by2));
   booth booth3(.i(1'b1), .y_signed(1'b0), .br(br3), .y({fracy,8'h00}), .by(by3));
   booth booth4(.i(1'b1), .y_signed(1'b0), .br(br4), .y({fracy,8'h00}), .by(by4));
   booth booth5(.i(1'b1), .y_signed(1'b0), .br(br5), .y({fracy,8'h00}), .by(by5));

   reg [50:18]   ms;
   reg [64:0]    m;


   wire [7:0]    expx = (x[30:23]==8'h00) ? 8'h01 : x[30:23];
   wire [7:0]    expy = (y[30:23]==8'h00) ? 8'h01 : y[30:23];
   reg [9:0]     expr;
   reg           subn;

   wire          sgnr = x[31]^y[31];

   wire [23:0]   fracx = {(x[30:23]!=8'h00),x[22:0]};
   assign        fracy = {(y[30:23]!=8'h00),y[22:0]};
   wire [25:0]   fracr;
   wire [30:0]   guard;
   wire          rnd;

   wire [5:0]    nrmsft;                                        // expr >= nrmsft : subnormal output
   wire [56:0]   nrmi,nrm0,nrm1,nrm2,nrm3,nrm4,nrm5;
   wire [5:0]    snci;
   wire [4:0]    snc5;
   wire [3:0]    snc4;
   wire [2:0]    snc3;
   wire [1:0]    snc2;
   wire          snc1;

   assign nrmsft[5] = snci[5] & (~(|nrmi[56:24])|(&nrmi[56:24]));
   assign nrmsft[4] = snc5[4] & (~(|nrm5[56:40])|(&nrm5[56:40]));
   assign nrmsft[3] = snc4[3] & (~(|nrm4[56:48])|(&nrm4[56:48]));
   assign nrmsft[2] = snc3[2] & (~(|nrm3[56:52])|(&nrm3[56:52]));
   assign nrmsft[1] = snc2[1] & (~(|nrm2[56:54])|(&nrm2[56:54]));
   assign nrmsft[0] = snc1    & (~(|nrm1[56:55])|(&nrm1[56:55]));

   assign snci[5:0] = (expr[8:6]!=3'h0)    ? 6'h3f : expr[5:0];
   assign snc5[4:0] = (snci[5]&~nrmsft[5]) ? 5'h1f : snci[4:0];
   assign snc4[3:0] = (snc5[4]&~nrmsft[4]) ? 4'hf  : snc5[3:0];
   assign snc3[2:0] = (snc4[3]&~nrmsft[3]) ? 3'h7  : snc4[2:0];
   assign snc2[1:0] = (snc3[2]&~nrmsft[2]) ? 2'h3  : snc3[1:0];
   assign snc1      = (snc2[1]&~nrmsft[1]) ? 1'h1  : snc2[0];

   assign {fracr[25:0],guard[30:0]} = (subn) ? {1'b0,{26{1'b0}},m[55:28],(|m[27:0])}
                                             : {1'b0,m[55:2],|m[1:0]};
   assign nrmi = {fracr,guard};
   assign nrm5 = (~nrmsft[5]) ? nrmi : {nrmi[24:0], 32'h0000};
   assign nrm4 = (~nrmsft[4]) ? nrm5 : {nrm5[40:0], 16'h0000};
   assign nrm3 = (~nrmsft[3]) ? nrm4 : {nrm4[48:0], 8'h00};
   assign nrm2 = (~nrmsft[2]) ? nrm3 : {nrm3[52:0], 4'h0};
   assign nrm1 = (~nrmsft[1]) ? nrm2 : {nrm2[54:0], 2'b00};
   assign nrm0 = (~nrmsft[0]) ? nrm1 : {nrm1[55:0], 1'b0};
   wire [1:0] ssn = {nrm0[30],(|nrm0[29:0])};
   wire [2:0] grsn = {nrm0[32:31],(|ssn)};

   assign rnd = (grsn[1:0]==2'b11)|(grsn[2:1]==2'b11);

   wire [9:0]  expn = expr-nrmsft+(nrm0[56]^nrm0[55]); // subnormal(+0) or normal(+1)

   always @ (posedge clk) begin
      if(req) begin
         subn <= 1'b0;
         expr <= expx + expy - 127 + 1;
         i<=5;
         xh<={8'h00,(x[30:23]!=8'h00),x[22:0]};
      end else if(i>=2) begin // cont cycl
         ng2 <= (br2[2:1]==2'b10)|(br2[2:0]==3'b110);
         ng5 <= (br5[2:1]==2'b10)|(br5[2:0]==3'b110);
         case(i)
           5: begin
              ms[50:26] <= {3'b000,by0[35:14]}+{1'b0,by1[35:12]}+{1'b0,by2[33:10]};
              ms[25:18] <= 8'h00;
              m[64:8] <= {7'h00,by3[35:0],               by0[13:0]}+
                         {5'h00,by4[35:0],1'b0,ng3,      by1[11:0],1'b0,ng0}+
                         {3'h0 ,by5[35:0],1'b0,ng4,2'b00,by2[ 9:0],1'b0,ng1,2'b00};
              m[7:0]  <= 8'h00;
           end
           4,3: begin
              ms[50:26] <= {3'b000,ms[50],~ms[50],ms[49:30]}+{1'b0,by1[35:12]}+{1'b0,by2[33:10]};
              ms[25:18] <= ms[29:22];
              m[64:8] <= {3'b000, m[64], ~m[64], m[63:12]}+
                         {5'h00,by4[35:0],1'b0,ng5,      by1[11:0],1'b0,ng2}+
                         {3'h0 ,by5[33:0],1'b0,ng4,2'b00,by2[ 9:0],1'b0,ng1,2'b00};
              m[7:0]  <= m[11:4];
           end
           2: begin
              m[64:0] <= m[64:0]+
                         {1'b0,by4[35:0],1'b0,ng5,26'h0}+
                         {       ms[50], ~ms[50], ms[49:18],1'b0,ng2,12'h0000};
              if((expr==0)|expr[9])begin
                 expr <= expr+26;
                 subn <= 1'b1;
              end
           end
         endcase
         i<=i-1;

         xh<={4'h0,xh[31:4]};
      end
   end

   always @(*) begin
      rslt[31] = sgnr;
      flag = 0;
      if((x[30:23]==8'hff)&(x[22:0]!=0))begin
         rslt = x|32'h00400000;
         flag[4]=~x[22]|((y[30:23]==8'hff)&~y[22]&(y[21:0]!=0));
      end else if((y[30:23]==8'hff)&(y[22:0]!=0))begin
         rslt = y|32'h00400000;
         flag[4]=~y[22]|((x[30:23]==8'hff)&~x[22]&(x[21:0]!=0));
      end else if(x[30:23]==8'hff)begin
         if(y[30:0]==0)begin
            rslt = 32'hffc00000;
            flag[4] = 1'b1;
         end else begin
            rslt[31:0] = {x[31]^y[31],x[30:0]};
         end
      end else if(y[30:23]==8'hff)begin
         if(x[30:0]==0)begin
            rslt = 32'hffc00000;
            flag[4] = 1'b1;
         end else begin
            rslt[31:0] = {x[31]^y[31],y[30:0]};
         end
      end else if({fracr,guard}==0)begin
         rslt[30:0] = 31'h00000000;
      end else if(expn[9])begin
         rslt[30:0] = 31'h00000000;
         flag[0] = 1'b1;
         flag[1] = 1'b1;
      end else if((expn[8:0]>=9'h0ff)&(~expn[9]))begin
         rslt[30:0] = 31'h7f800000;
         flag[0] = 1'b1;
         flag[2] = 1'b1;
      end else begin
         rslt[30:0] = {expn[7:0],nrm0[54:32]}+rnd;
         flag[0]=|grsn[1:0];
         flag[1]=((rslt[30:23]==8'h00)|((expn[7:0]==8'h00)&~ssn[1]))&(flag[0]);
         flag[2]=(rslt[30:23]==8'hff);
      end
   end

endmodule

module booth
  (
   input             i,
   input             y_signed,
   input [2:0]       br,
   input [31:0]      y,
   output reg [35:0] by
   );

   wire              S = ((br==3'b000)|(br==3'b111)) ? 1'b0 : (y[31]&y_signed)^br[2] ;

   always @(*) begin
      case(br)
        3'b000: by[32:0] =  {33{1'b0}};
        3'b001: by[32:0] =  {y[31]&y_signed,y[31:0]};
        3'b010: by[32:0] =  {y[31]&y_signed,y[31:0]};
        3'b011: by[32:0] =  {y[31:0],1'b0};
        3'b100: by[32:0] = ~{y[31:0],1'b0};
        3'b101: by[32:0] = ~{y[31]&y_signed,y[31:0]};
        3'b110: by[32:0] = ~{y[31]&y_signed,y[31:0]};
        3'b111: by[32:0] =  {33{1'b0}};
      endcase
      if(i) by[35:33] = {2'b01,~S};
      else  by[35:33] = {~S,S,S};
   end
endmodule
