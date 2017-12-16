# Verilator と Berkeley TestFloat を使って FPU 演算器の検証を加速する
Berkeley TestFloat で生成したテスト入力と期待値を使って FPU 演算器の検証をします。  
TestFloat の出力を標準入力から受け取りたいので、Verilator を使って C++ で記述したテストベンチで検証します。  
TestFloat に限らず、C で入力データと期待値を生成したい場合に応用が利くと思います。  
Verilator のテストベンチは書きにくいといわれていますが、```@(negedge clk)``` に代わる関数を定義することでテストベンチを書きやすくしてます。

## 準備
Windows Subsystem for Unix の Ubuntu 上で試しています  
#### このリポジトリをクローン
softfloat と testfloat もまとめてクローンします。
```
$ git clone --recursive https://github.com/tom01h/float_test
```

#### TestFloat をビルド
```
$ cd ${path_to_float_test}/berkeley-softfloat-3/build/Linux-x86_64-GCC/
$ make
$ cd ${path_to_float_test}/berkeley-testfloat-3/build/Linux-x86_64-GCC/
$ make
```

#### TestFloat の確認
単精度 MUL の場合
```
$ ${path_to_float_test}/berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen f32_mul
```
こんな感じのが出てくればOK  
意味は、```入力1 入力2 演算結果 フラグ``` の順です
```
(略)
BF201FFF FFFFFFFE FFFFFFFE 00
C00007EF 3DFFF7BF BE8003CE 01
FFFFFFFE FFFFFFFE FFFFFFFE 00
```

## テストベンチの作成
まずは Verilog のテストベンチ用に ```@(negedge clk)``` の代わりの関数を定義します。  
トップの宣言が ```Vfmul_4* verilator_top = new Vfmul_4;``` で、サイクルタイムが 100 なら、

```
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
```
この関数をメインループの中で下のように呼ぶと1サイクル進みます。  
まさに ```@(negedge clk)``` の代わりです。
```
main_time = eval(main_time, verilator_top, tfp);
```
メインループでは、最初に標準入力から TestFloat の出力を受け取ります。
```
  while (1) {
    if(scanf("%08x %08x %08x %02x", &x, &y, &ex_rslt, &ex_flag)==EOF){break;}
```
そして入力信号とリクエストバリッドをセット
```
    verilator_top->reset = 1;
    verilator_top->req   = 1;
    verilator_top->x = x;
    verilator_top->y = y;
```
1サイクル後にリクエストバリッドをネゲート
```
    main_time = eval(main_time, verilator_top, tfp);

    verilator_top->reset = 0;
    verilator_top->req   = 0;
```
必要なサイクル数だけ ```@(negedge clk)``` で進めた後に結果を確認
```
    (略)
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
```

## 検証の実行

```
$ cd ${path_to_float_test}
$ make
$ berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen f32_mul | sim/Vfmul_4
```
