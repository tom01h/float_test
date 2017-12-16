#include "unistd.h"
#include "getopt.h"
#include "Vfmul_4.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>

#define VCD_PATH_LENGTH 256

vluint64_t eval(vluint64_t main_time, Vfmul_4* verilator_top, VerilatedVcdC* tfp)
{
  verilator_top->clk = 0;
  verilator_top->eval();
  tfp->dump(main_time);

  verilator_top->clk = 1;
  verilator_top->eval();
  tfp->dump(main_time+50);

  return main_time + 100;
}

int main(int argc, char **argv, char **env) {
  
  int x, y;
  int xe, ye;
  int i;
  char *e;
  char vcdfile[VCD_PATH_LENGTH];

  int flag, ex_flag, rslt, ex_rslt;

  strncpy(vcdfile,"tmp.vcd",VCD_PATH_LENGTH);
  srand((unsigned)time(NULL));
  
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  VerilatedVcdC* tfp = new VerilatedVcdC;
  Vfmul_4* verilator_top = new Vfmul_4;
  verilator_top->trace(tfp, 99); // requires explicit max levels param
  tfp->open(vcdfile);
  vluint64_t main_time = 0;

  i=0;
  while (1) {
    if(scanf("%08x %08x %08x %02x", &x, &y, &ex_rslt, &ex_flag)==EOF){break;}

    verilator_top->reset = 1;
    verilator_top->req   = 1;
    verilator_top->x = x;
    verilator_top->y = y;

    main_time = eval(main_time, verilator_top, tfp);

    verilator_top->reset = 0;
    verilator_top->req   = 0;

    main_time = eval(main_time, verilator_top, tfp);
    main_time = eval(main_time, verilator_top, tfp);
    main_time = eval(main_time, verilator_top, tfp);
    main_time = eval(main_time, verilator_top, tfp);
    main_time = eval(main_time, verilator_top, tfp);
    main_time = eval(main_time, verilator_top, tfp);
    main_time = eval(main_time, verilator_top, tfp);
    main_time = eval(main_time, verilator_top, tfp);
    main_time = eval(main_time, verilator_top, tfp);


    flag = verilator_top->flag;
    rslt = verilator_top->rslt;
    if((rslt==ex_rslt)&(flag==ex_flag)){
      printf("PASSED %04d : %08x * %08x = %08x .. %02x\n",i,x,y,rslt,flag&0xff);
    }else{
      printf("FAILED %04d : %08x * %08x = %08x .. %02x != %08x .. %02x\n",i,x,y,ex_rslt,ex_flag&0xff,rslt,flag&0xff);
    }

    i++;

  }
  delete verilator_top;
  tfp->close();

  
  exit(0);
}
