`ifdef SYNTHESIS
    assign active_path = in_a & in_b;
`else
    initial $display("sim only");
    wire sim_only;
`endif
