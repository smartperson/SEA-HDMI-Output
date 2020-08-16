`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/05/2020 01:10:06 AM
// Design Name: 
// Module Name: bg_compositor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bg_compositor
    #(  parameter  RAM_READ_START_CYCLE    = 5'b11001,
        parameter  RAM_MAP_ADDR            = 15'h2000
    )
    (
    input wire [15:0] i_x_raw,
    input wire [15:0] i_y_raw,
    input wire i_v_sync,
    input wire i_pix_clk,
    input wire [15:0] i_in_data,
    input wire i_btn,
    output wire o_ram_enable,
    output wire [14:0] o_addr,
    
    output wire [2:0] o_palette,
    output wire [3:0] o_color,
    output wire o_priority
    );

//    reg [15:0] sprite_x     = 16'd00;
//    reg [15:0] sprite_y     = 16'd00;
    reg sprite_y_flip       = 0;
    wire sprite_hit_x, sprite_hit_y;
    wire [2:0] sprite_render_x;
    wire [2:0] sprite_render_y;
    
    reg [15:0] i_x, i_y;
    reg [10:0] x_scroll = 0;
    reg [9:0] y_scroll;
    reg [3:0] counter;

    //assign i_x = i_x_raw + x_scroll;
    assign i_y = i_y_raw + y_scroll;
    assign i_x = i_x_raw + x_scroll;
    
    reg curr_tile_index;
    always @(negedge i_pix_clk) begin
        curr_tile_index <= (((i_x[4:0]+1) & 31) >= (x_scroll & 31)) ? 0 : 1; //>=? 
    end 
    
    always @(posedge i_v_sync) begin
        if (RAM_MAP_ADDR == 15'h2000)
            counter <= counter+1;
//        else
//            if (x_scroll < 2048)
//                x_scroll <= x_scroll+1;
//            else
//                x_scroll <= 0;
    end

    always @(posedge counter[3]) begin
        if (RAM_MAP_ADDR == 15'h2000)
            if (x_scroll < 2048)
                x_scroll <= x_scroll+1;
            else
                x_scroll <= 0;
    end
    
//    always @(posedge i_btn) begin
//        if (RAM_MAP_ADDR == 15'h2000)
//            x_scroll <= x_scroll+1;
//    end

    
    assign sprite_hit_x = 1;
    assign sprite_hit_y = 1;
    
    assign sprite_render_x = i_x[4:2]; //TODO is this still right? Causing problems?
    assign sprite_render_y = i_y[4:2];
    reg [2:0] selected_palette;
    reg [3:0] selected_color;

    reg reg_ram_enable;
    reg [14:0]reg_addr;
    //reg [15:0]reg_ram;
    reg [9:0]reg_tile_number;
    reg [0:2][7:0]reg_tile_attr;
    reg [0:2][0:31] reg_tile_data;
        
    wire [1:0]x_attr_bits;
    assign x_attr_bits = i_x[6:5];
    always @(negedge i_pix_clk) begin
//        case (i_x_raw[4:0])
//            5'b11111: begin
//                sprite_y_flip <= reg_tile_attr[curr_tile_index+1][5];
//                // bit 3 has priority, figure out how/what to assign it to here
//            end
//        endcase
//        if (sprite_x_flip)
//            selected_color <= {reg_tile_data[curr_tile_index][(7-sprite_render_x)+24],
//                               reg_tile_data[curr_tile_index][(7-sprite_render_x)+16],
//                               reg_tile_data[curr_tile_index][(7-sprite_render_x)+8],
//                               reg_tile_data[curr_tile_index][(7-sprite_render_x)]
//                               };
//        else
            selected_color <= {reg_tile_data[curr_tile_index][sprite_render_x+24],
                               reg_tile_data[curr_tile_index][sprite_render_x+16],
                               reg_tile_data[curr_tile_index][sprite_render_x+8],
                               reg_tile_data[curr_tile_index][sprite_render_x]
                               };
    end
    always @(negedge i_pix_clk) begin
        case (i_x_raw[4:0])
            RAM_READ_START_CYCLE: begin
                reg_ram_enable <= 1;
                if ((i_x + 64) >= 1024 && i_x_raw < 1280)
                    reg_addr <= RAM_MAP_ADDR+15'h400 + i_y[15:5]*32 + i_x[9:5] + 2 + 32;// + (i_x_raw > 1280 ? -32 : 0); // i_x[9:5]? +1?
                else
                    reg_addr <= RAM_MAP_ADDR+15'h000 + i_y[15:5]*32 + 2 + i_x[9:5] + ((i_x_raw+64) > 1280  ? +0 : +32); //: (i_y[15:5]*32 + 2));
            end
            RAM_READ_START_CYCLE+1: begin
//                reg_ram_enable <= 0;
                reg_tile_number <= i_in_data[9:0];
                reg_tile_attr[2] <= i_in_data[15:10];
            end
            RAM_READ_START_CYCLE+2: begin
                reg_ram_enable <= 1;
                if (reg_tile_attr[2][5]) //y flip?
                    reg_addr <= 15'b000000000000000 + (reg_tile_number*16) + (7-sprite_render_y);
                else
                    reg_addr <= 15'b000000000000000 + (reg_tile_number*16) + sprite_render_y;
            end
            RAM_READ_START_CYCLE+3: begin
                if (reg_tile_attr[2][4]) begin //x flip?
                    integer i;
                    for(i=0;i<8;i=i+1)
                        reg_tile_data[2][i] = i_in_data[i+8]; //i_in_data[7-i];
                    for(i=8;i<16;i=i+1)
                        reg_tile_data[2][i] = i_in_data[i-8]; //i_in_data[7-i+16];
                end
                else
                    reg_tile_data[2][0:15] <= i_in_data;
            end
            RAM_READ_START_CYCLE+4: begin
                if (reg_tile_attr[2][5]) // y flip?
                    reg_addr <= 15'b000000000000000 + (reg_tile_number*16) + (7 -sprite_render_y + 8);
                else
                    reg_addr <= 15'b000000000000000 + (reg_tile_number*16) + sprite_render_y + 8;
            end
            RAM_READ_START_CYCLE+5: begin
                if (reg_tile_attr[2][4]) begin//x flip
                    integer i;
                    for(i=16;i<24;i=i+1)
                        reg_tile_data[2][i] = i_in_data[i-16+8]; //i_in_data[7-i+16];
                    for(i=24;i<32;i=i+1)
                        reg_tile_data[2][i] = i_in_data[i-16-8]; //i_in_data[7-i+32];
                end
                else
                    reg_tile_data[2][16:31] <= i_in_data;
            end
            RAM_READ_START_CYCLE+6: begin
                reg_ram_enable <= 0;
            end
            5'b11111: begin //this one should always be done on the last clock cycle for the tile
                reg_ram_enable <= 0;
                reg_tile_data[0] = reg_tile_data[1];
                reg_tile_data[1] = reg_tile_data[2];
                reg_tile_attr[0] = reg_tile_attr[1];
                reg_tile_attr[1] = reg_tile_attr[2];
            end
            default: ; 
        endcase
    end
    assign o_ram_enable = reg_ram_enable;
    assign o_addr   = reg_addr;
//    assign o_red    = (sprite_hit_x && sprite_hit_y) ? palette_colors[selected_palette][selected_color][2] : 8'hXX;
//    assign o_green  = (sprite_hit_x && sprite_hit_y) ? palette_colors[selected_palette][selected_color][1] : 8'hXX;
//    assign o_blue   = (sprite_hit_x && sprite_hit_y) ? palette_colors[selected_palette][selected_color][0] : 8'hXX;
    reg [7:0] reg_red, reg_green, reg_blue;
    assign o_palette    = selected_palette;
    assign o_color  = selected_color;
    assign o_priority   =  1; //TODO incorporate selected_priority;
    always @(posedge i_pix_clk) begin
//        if (i_x_raw[4:0] == 5'b11111)
            selected_palette <= reg_tile_attr[curr_tile_index][2:0]; //+1?
    end
endmodule
