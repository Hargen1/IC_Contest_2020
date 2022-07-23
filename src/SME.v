module SME ( clk, reset, chardata, isstring, ispattern, valid, match, match_index);
input clk;
input reset;
input [7:0] chardata;
input isstring;
input ispattern;
output valid;
output match;
output [4:0] match_index;

reg [7:0] string[0:31];
reg [7:0] pattern[0:7];

reg match;
reg valid;
reg valid_temp;
reg match_temp;
reg match_done;
reg star_flag;
reg match_t;
reg beg_flag;
reg [4:0] match_index;

reg [2:0] state;
reg [2:0] n_state;

reg [5:0] string_cnt;			//string size
reg [5:0] string_cnt_temp;
reg [3:0] pattern_cnt;			//pattern size

reg [4:0] star_index;
reg [5:0] string_index_temp;		//string index counter for compare state
reg [5:0] string_index;			
reg [3:0] pattern_index;		

parameter IDLE = 3'b000;
parameter STR  = 3'b001;
parameter PAT  = 3'b010;
parameter DEC  = 3'b011;
parameter OUT  = 3'b100;

integer i;

// FSM
always@(posedge clk or posedge reset) begin
    if(reset) begin
       state <= IDLE; 
    end
    else begin
       state <= n_state;
    end
end

// FSM next state assignment
always@(*) begin
    case(state) 
         IDLE: begin
                  if(isstring) n_state = STR;
                  else if (ispattern) n_state = PAT;
                  else n_state = state;             
         end      
         STR: begin
                  if(ispattern) n_state = PAT;
                  else n_state = state;
         end      
         PAT: begin  
                  if(!ispattern) n_state = DEC; 
                  else n_state = state;
         end
         DEC: begin 
                 if(match_done) n_state = OUT;
                 else n_state = state;
         end
         OUT: begin
         		if(!valid_temp) n_state = IDLE;
                 else n_state = state;
         end
         default: n_state = state;
    endcase
end

//str_cnt
always @(posedge clk or posedge reset) begin
	if (reset) begin
		string_cnt <= 0;
	end
	else begin
		case(n_state)
			STR: begin
				if (isstring) begin
					string_cnt <= string_cnt + 1;
				end
				else begin
					string_cnt <= string_cnt;
				end
			end
			OUT: begin
					string_cnt <= 0;
				 end 
			default: begin
				string_cnt <= string_cnt;
			end				
		endcase
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		string_cnt_temp <= 0;
		
	end
	else if (isstring) begin
	    string_cnt_temp <= string_cnt;
	end
	else begin
		string_cnt_temp <= string_cnt_temp;
	end
end

//pat_cnt
always @(posedge clk or posedge reset) begin
	if (reset) begin
		pattern_cnt <= 0;
	end
	else begin
		case(n_state)
			PAT: begin
				if (ispattern) begin
					pattern_cnt <= pattern_cnt + 1;
				end
				else begin
					pattern_cnt <= pattern_cnt;
				end
			end
			OUT: pattern_cnt <= 0;
			default: pattern_cnt <= pattern_cnt;
		endcase
	end
end

//input data
always @(posedge clk or posedge reset) begin
	if (reset) begin
		for(i = 0; i <8; i=i+1) begin
			pattern[i] <= 8'b0;
		end		
    end
    else begin
    	case(n_state)
    		PAT: begin
    			if (ispattern) begin
    				pattern[pattern_cnt] <= chardata;
    			end
    			else begin
    				pattern[pattern_cnt] <= pattern[pattern_cnt];		
    			end
    		end
    		default: begin
    			for(i = 0; i < 8; i= i + 1) begin
					pattern[i] <= pattern[i];
				end
    		end
    	endcase
    end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		for(i = 0; i <32; i=i+1)begin
			string[i] <= 8'b0;
		end
	end
	else begin
		case(n_state)
			STR: begin
    			if (isstring) begin
    				string[string_cnt] <= chardata; 
    			end
    			else begin
    				string[string_cnt] <= string[string_cnt];
    			end
    		end
    		default: begin
    			for(i = 0; i < 32; i = i + 1)begin
					string[i] <= string[i];
				end
    		end
		endcase
	end
end

//DEC
always @(posedge clk or posedge reset) begin
	if (reset) begin
		string_index <= 0;
		pattern_index <= 0;
		string_index_temp <= 0;	
	end
	else begin
		case(state)	//(2E = .)(5E = ^)(24 = $)(2A = *)(20 = space)
			PAT: begin
				pattern_index <= 0;
				string_index <= 0;
				string_index_temp <= 0;
			end 
			DEC: begin
				if (pattern[pattern_index] == 8'h24 && (string[string_index] == 8'h20 || string_index == string_cnt_temp + 1)) begin
					pattern_index <= pattern_index;
					string_index <= string_index;
					string_index_temp <= string_index_temp;
				end
				else if (string[string_index] == pattern[pattern_index] || pattern[pattern_index] == 8'h2E) begin
					if (pattern_index + 1 < pattern_cnt) begin
						string_index  <= string_index  + 1;
						pattern_index <= pattern_index + 1;
						string_index_temp <= string_index_temp;
					end
					else begin
						pattern_index <= pattern_index;
						string_index <= string_index;
						string_index_temp <= string_index_temp;
					end
				end

				else if (pattern[pattern_index] == 8'h2A) begin
					pattern_index <= pattern_index + 1;
					string_index <= string_index;
					string_index_temp <= string_index_temp;
				end

				else if (pattern[0] == 8'h5E && string_index == 0 && ((string[string_index + 5'd1] == pattern[pattern_index + 5'd1]) || pattern[pattern_index + 5'd1] == 8'h2E)) begin
					string_index  <= string_index  + 1;
					pattern_index <= pattern_index + 1;
					string_index_temp <= string_index_temp;
				end

				else if (pattern[0] == 8'h5E && string[string_index] == 8'h20 && ((string[string_index + 5'd1] == pattern[pattern_index + 5'd1]) || pattern[pattern_index + 5'd1] == 8'h2E)) begin
					string_index  <= string_index  + 1;
					pattern_index <= pattern_index + 1;
					string_index_temp <= string_index_temp;
				end
				else begin
					if (star_flag == 1 && string_index < string_cnt_temp + 1) begin
						if (beg_flag == 1 && string[string_index] == 8'h20) begin
							pattern_index <= pattern_index;
							string_index <= string_index;
							string_index_temp <= string_index_temp;
						end
						else begin
							string_index_temp <= string_index_temp + 1;
							string_index      <= string_index + 1;
							pattern_index <= star_index;
						end
					end
					else if (string_index  == string_cnt_temp + 1) begin
						pattern_index <= pattern_index;
						string_index <= string_index;
						string_index_temp <= string_index_temp;
					end
					else begin
						string_index_temp <= string_index_temp + 1;
						string_index      <= string_index_temp + 1;
						pattern_index     <= 4'b0000;
					end
				end
			end
			OUT: begin
				string_index <= 0;
				pattern_index <= 0;
				string_index_temp <= 0;
			end
			default: begin
				string_index <= string_index;
				pattern_index <= pattern_index;
				string_index_temp <= string_index_temp;
			end
		endcase
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		beg_flag <= 0;
	end
	else begin
		case(state)
			PAT: beg_flag <= 0;
			DEC: begin
				if (pattern[0] == 8'h5E && string_index == 0 && ((string[string_index + 5'd1] == pattern[pattern_index + 5'd1]) || pattern[pattern_index + 5'd1] == 8'h2E)) begin
					beg_flag <= 1;
				end
				else if (pattern[0] == 8'h5E && string[string_index] == 8'h20 && ((string[string_index + 5'd1] == pattern[pattern_index + 5'd1]) || pattern[pattern_index + 5'd1] == 8'h2E)) begin
					beg_flag <= 1;
				end
				else begin
					beg_flag <= beg_flag;
				end
			end
			default: beg_flag <= beg_flag;
		endcase
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		match_t  <= 0;
		valid_temp <= 0;
	end
	else begin
		case(state)
			OUT: begin
				valid_temp <= 1;
				match_t <= match_temp;			
			end 
			default: begin
				valid_temp <= 0;
				match_t <= 0;
			end 
		endcase
	end
end

// Valid buffer
always @(posedge clk or posedge reset) begin
	if (reset) begin
		valid <= 0;
		match <= 0;
	end
	else  begin
		valid <= valid_temp;
		match <= match_t;
	end
end


always @(posedge clk or posedge reset) begin
	if (reset) begin
		match_done <= 0;
		match_temp <= 0;
	end
	else begin
		case(state)
			PAT: begin
				match_done <= 0;
				match_temp <= 0;
			end
			DEC: begin
				if (pattern[pattern_index] == 8'h24 && (string[string_index] == 8'h20 || string_index == string_cnt_temp + 1)) begin
					match_done <= 1;
					match_temp <= 1;
				end
				else if (string[string_index] == pattern[pattern_index] || pattern[pattern_index] == 8'h2E) begin
					if (pattern_index + 1 < pattern_cnt) begin
						match_done <= match_done;
						match_temp <= match_temp;
					end 
					else begin
						match_done <= 1;
						match_temp <= 1;
					end 
				end
				else begin
					if (star_flag == 1 && string_index < string_cnt_temp + 1) begin
						if (beg_flag == 1 && string[string_index] == 8'h20) begin
							match_done <= 1;
							match_temp <= 0;
						end
						else begin
							match_done <= match_done;
						end
					end
					else if (string_index  == string_cnt_temp + 1) begin
						match_done <= 1;
						match_temp <= 0;
					end
					else begin
						match_done <= match_done;
						match_temp <= match_temp;
					end
				end
			end
			default: begin
				match_done <= match_done;
				match_temp <= match_temp;
			end 
		endcase
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		star_flag <= 0;
		star_index <= 0;
	end
	else begin
		case(state)
			PAT: begin
				star_flag <= 0;
				star_index <= 0;
			end
			DEC: begin
				if (pattern[pattern_index] == 8'h2A) begin
					star_flag <= 1;
					star_index <= pattern_index + 1;
				end
				else begin
					star_flag <= star_flag;
					star_index <= star_index;
				end
			end
			default: begin
				star_flag <= 0;
				star_index <= 0;
			end
		endcase
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		match_index <= 0;
	end
	else begin
		case(state)
			PAT: match_index <= 0;
			DEC: begin
				if (string[string_index] == pattern[pattern_index] || pattern[pattern_index] == 8'h2E) begin
					if (pattern_index + 1 < pattern_cnt) begin
						if(pattern_index == 0) match_index <= string_index;	
						else match_index <= match_index;
					end
					else begin
						if(pattern_index == 0) match_index <= string_index;	
						else match_index <= match_index;
					end
				end
				else if (pattern[0] == 8'h5E && string_index == 0 && ((string[string_index + 5'd1] == pattern[pattern_index + 5'd1]) || pattern[pattern_index + 5'd1] == 8'h2E)) begin
					match_index <= string_index;
				end
				else if (pattern[0] == 8'h5E && string[string_index] == 8'h20 && ((string[string_index + 5'd1] == pattern[pattern_index + 5'd1]) || pattern[pattern_index + 5'd1] == 8'h2E)) begin
					match_index <= string_index  + 1;
				end
				else begin
					match_index <= match_index;
				end
			end
			default: match_index <= match_index;
		endcase
	end
end


endmodule

