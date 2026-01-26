module alu #(
    parameter DATA_W =32,
    parameter SHAMT_W = 5,
    parameter OP =3
)(
    input wire [DATA_W-1:0] a,
    input wire [DATA_W-1:0] b,
    input wire [OP-1:0]     s,
    input wire              ext,
    output reg [DATA_W-1:0] y
);

    wire [SHAMT_W-1:0] shamt = b[SHAMT_W-1:0]; //SHAMT= Shift amount

    always @(*) begin
        case (s)
        3'b000: y= ext ? (a-b) : (a+b); // ADD bolon SUB iig ext ga set bolson ued shiideh heseg
        3'b111: y= a & b;               // AND
        3'b110: y= a | b;               // OR
        3'b100: y= a ^ b;               // XOR
        3'b001: y= a << shamt;          // SLL
        3'b101:  begin
            if (ext)
                y = $signed(a) >>> shamt; //arithmetic shift right
            else
                y = a >> shamt;         //logical shift right
        end
        default: y=0;
     endcase
    end
endmodule
