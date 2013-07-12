-- ZPU
--
-- Copyright 2004-2008 oharboe - �yvind Harboe - oyvind.harboe@zylin.com
-- 
-- The FreeBSD license
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above
--    copyright notice, this list of conditions and the following
--    disclaimer in the documentation and/or other materials
--    provided with the distribution.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE ZPU PROJECT ``AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
-- ZPU PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
-- INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
-- STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-- 
-- The views and conclusions contained in the software and documentation
-- are those of the authors and should not be interpreted as representing
-- official policies, either expressed or implied, of the ZPU Project.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library work;
use work.zpu_config.all;
use work.zpupkg.all;

entity SDRAMTest_ROM is
port (
	clk : in std_logic;
	areset : in std_logic := '0';
	from_zpu : in ZPU_ToROM;
	to_zpu : out ZPU_FromROM
);
end SDRAMTest_ROM;

architecture arch of SDRAMTest_ROM is

type ram_type is array(natural range 0 to ((2**(maxAddrBitBRAM+1))/4)-1) of std_logic_vector(wordSize-1 downto 0);

shared variable ram : ram_type :=
(
     0 => x"a0809380",
     1 => x"04000000",
     2 => x"800b810b",
     3 => x"ff8c0c04",
     4 => x"0b0b0ba0",
     5 => x"80809d0b",
     6 => x"810bff8c",
     7 => x"0c700471",
     8 => x"fd060872",
     9 => x"83060981",
    10 => x"05820583",
    11 => x"2b2a83ff",
    12 => x"ff065204",
    13 => x"71fc0608",
    14 => x"72830609",
    15 => x"81058305",
    16 => x"1010102a",
    17 => x"81ff0652",
    18 => x"0471fc06",
    19 => x"080ba080",
    20 => x"93ec7383",
    21 => x"06101005",
    22 => x"08067381",
    23 => x"ff067383",
    24 => x"06098105",
    25 => x"83051010",
    26 => x"102b0772",
    27 => x"fc060c51",
    28 => x"51040000",
    29 => x"02f8050d",
    30 => x"028f05a0",
    31 => x"8080b42d",
    32 => x"52ff8408",
    33 => x"70882a70",
    34 => x"81065151",
    35 => x"5170802e",
    36 => x"f03871ff",
    37 => x"840c0288",
    38 => x"050d0402",
    39 => x"f4050d74",
    40 => x"5372a080",
    41 => x"80b42d70",
    42 => x"81ff0652",
    43 => x"5270802e",
    44 => x"a3387181",
    45 => x"ff068114",
    46 => x"5452ff84",
    47 => x"0870882a",
    48 => x"70810651",
    49 => x"51517080",
    50 => x"2ef03871",
    51 => x"ff840ca0",
    52 => x"8081a104",
    53 => x"028c050d",
    54 => x"0402f805",
    55 => x"0d028f05",
    56 => x"a08080b4",
    57 => x"2d52ff84",
    58 => x"0870882a",
    59 => x"70810651",
    60 => x"51517080",
    61 => x"2ef03871",
    62 => x"ff840c02",
    63 => x"88050d04",
    64 => x"02d0050d",
    65 => x"02b405a0",
    66 => x"8081d971",
    67 => x"70840553",
    68 => x"085c5c58",
    69 => x"807a7081",
    70 => x"055ca080",
    71 => x"80b42d54",
    72 => x"5972792e",
    73 => x"82cc3872",
    74 => x"a52e0981",
    75 => x"0682ab38",
    76 => x"79708105",
    77 => x"5ba08080",
    78 => x"b42d5372",
    79 => x"80e42e9f",
    80 => x"387280e4",
    81 => x"248d3872",
    82 => x"80e32e81",
    83 => x"c438a080",
    84 => x"84a30472",
    85 => x"80f32e81",
    86 => x"8d38a080",
    87 => x"84a30477",
    88 => x"84197108",
    89 => x"a0809a84",
    90 => x"0ba08099",
    91 => x"b4595a56",
    92 => x"59538056",
    93 => x"73762e09",
    94 => x"81069538",
    95 => x"b00ba080",
    96 => x"99b40ba0",
    97 => x"8080c92d",
    98 => x"811555a0",
    99 => x"8083b804",
   100 => x"738f06a0",
   101 => x"8093fc05",
   102 => x"5372a080",
   103 => x"80b42d75",
   104 => x"70810557",
   105 => x"a08080c9",
   106 => x"2d73842a",
   107 => x"5473e138",
   108 => x"74a08099",
   109 => x"b42e9c38",
   110 => x"ff155574",
   111 => x"a08080b4",
   112 => x"2d777081",
   113 => x"0559a080",
   114 => x"80c92d81",
   115 => x"1656a080",
   116 => x"83b00480",
   117 => x"77a08080",
   118 => x"c92d75a0",
   119 => x"809a8456",
   120 => x"54a08084",
   121 => x"b7047784",
   122 => x"19710857",
   123 => x"59538075",
   124 => x"a08080b4",
   125 => x"2d545472",
   126 => x"742ebc38",
   127 => x"81147016",
   128 => x"70a08080",
   129 => x"b42d5154",
   130 => x"5472f138",
   131 => x"a08084b7",
   132 => x"04778419",
   133 => x"8312a080",
   134 => x"80b42d52",
   135 => x"5953a080",
   136 => x"84da0480",
   137 => x"52a5517a",
   138 => x"2d805272",
   139 => x"517a2d82",
   140 => x"1959a080",
   141 => x"84e30473",
   142 => x"ff155553",
   143 => x"807325a3",
   144 => x"38747081",
   145 => x"0556a080",
   146 => x"80b42d53",
   147 => x"80527251",
   148 => x"7a2d8119",
   149 => x"59a08084",
   150 => x"b7048052",
   151 => x"72517a2d",
   152 => x"81195979",
   153 => x"7081055b",
   154 => x"a08080b4",
   155 => x"2d5372fd",
   156 => x"b63878a0",
   157 => x"8099a40c",
   158 => x"02b0050d",
   159 => x"0402f405",
   160 => x"0d747671",
   161 => x"81ff06c8",
   162 => x"0c5353a0",
   163 => x"809ac408",
   164 => x"85387189",
   165 => x"2b527198",
   166 => x"2ac80c71",
   167 => x"902a7081",
   168 => x"ff06c80c",
   169 => x"5171882a",
   170 => x"7081ff06",
   171 => x"c80c5171",
   172 => x"81ff06c8",
   173 => x"0c72902a",
   174 => x"7081ff06",
   175 => x"c80c51c8",
   176 => x"087081ff",
   177 => x"06515182",
   178 => x"b8bf5270",
   179 => x"81ff2e09",
   180 => x"81069438",
   181 => x"81ff0bc8",
   182 => x"0cc80870",
   183 => x"81ff06ff",
   184 => x"14545151",
   185 => x"71e53870",
   186 => x"a08099a4",
   187 => x"0c028c05",
   188 => x"0d0402fc",
   189 => x"050d81c7",
   190 => x"5181ff0b",
   191 => x"c80cff11",
   192 => x"51708025",
   193 => x"f4380284",
   194 => x"050d0402",
   195 => x"f0050da0",
   196 => x"8085f22d",
   197 => x"819c9f53",
   198 => x"805287fc",
   199 => x"80f751a0",
   200 => x"8084fd2d",
   201 => x"a08099a4",
   202 => x"0854a080",
   203 => x"99a40881",
   204 => x"2e098106",
   205 => x"ab3881ff",
   206 => x"0bc80c82",
   207 => x"0a52849c",
   208 => x"80e951a0",
   209 => x"8084fd2d",
   210 => x"a08099a4",
   211 => x"088d3881",
   212 => x"ff0bc80c",
   213 => x"7353a080",
   214 => x"86e704a0",
   215 => x"8085f22d",
   216 => x"ff135372",
   217 => x"ffb23872",
   218 => x"a08099a4",
   219 => x"0c029005",
   220 => x"0d0402f4",
   221 => x"050d81ff",
   222 => x"0bc80c93",
   223 => x"53805287",
   224 => x"fc80c151",
   225 => x"a08084fd",
   226 => x"2da08099",
   227 => x"a4088d38",
   228 => x"81ff0bc8",
   229 => x"0c8153a0",
   230 => x"8087a704",
   231 => x"a08085f2",
   232 => x"2dff1353",
   233 => x"72d73872",
   234 => x"a08099a4",
   235 => x"0c028c05",
   236 => x"0d0402f0",
   237 => x"050da080",
   238 => x"85f22d83",
   239 => x"aa52849c",
   240 => x"80c851a0",
   241 => x"8084fd2d",
   242 => x"a08099a4",
   243 => x"08812e09",
   244 => x"81068e38",
   245 => x"cc0883ff",
   246 => x"ff065372",
   247 => x"83aa2ea3",
   248 => x"38a08086",
   249 => x"f22da080",
   250 => x"87fc0481",
   251 => x"54a08089",
   252 => x"9304a080",
   253 => x"949051a0",
   254 => x"8082802d",
   255 => x"8054a080",
   256 => x"89930481",
   257 => x"ff0bc80c",
   258 => x"b153a080",
   259 => x"868b2da0",
   260 => x"8099a408",
   261 => x"802e80e2",
   262 => x"38805287",
   263 => x"fc80fa51",
   264 => x"a08084fd",
   265 => x"2da08099",
   266 => x"a408bf38",
   267 => x"a08099a4",
   268 => x"0852a080",
   269 => x"94ac51a0",
   270 => x"8082802d",
   271 => x"81ff0bc8",
   272 => x"0cc80881",
   273 => x"ff067053",
   274 => x"a08094b8",
   275 => x"5254a080",
   276 => x"82802dcc",
   277 => x"0874862a",
   278 => x"70810670",
   279 => x"57515153",
   280 => x"72802eaf",
   281 => x"38a08087",
   282 => x"eb04a080",
   283 => x"99a40852",
   284 => x"a08094ac",
   285 => x"51a08082",
   286 => x"802d7282",
   287 => x"2efef338",
   288 => x"ff135372",
   289 => x"ff8438a0",
   290 => x"8094c851",
   291 => x"a080819b",
   292 => x"2d725473",
   293 => x"a08099a4",
   294 => x"0c029005",
   295 => x"0d0402f4",
   296 => x"050d810b",
   297 => x"a0809ac4",
   298 => x"0cc40870",
   299 => x"8f2a7081",
   300 => x"06515153",
   301 => x"72f33872",
   302 => x"c40ca080",
   303 => x"85f22dc4",
   304 => x"08708f2a",
   305 => x"70810651",
   306 => x"515372f3",
   307 => x"38810bc4",
   308 => x"0c875380",
   309 => x"5284d480",
   310 => x"c051a080",
   311 => x"84fd2da0",
   312 => x"8099a408",
   313 => x"812e0981",
   314 => x"068738a0",
   315 => x"8099a408",
   316 => x"53a08094",
   317 => x"e051a080",
   318 => x"819b2d72",
   319 => x"822e0981",
   320 => x"069238a0",
   321 => x"8094f451",
   322 => x"a080819b",
   323 => x"2d8053a0",
   324 => x"808b8404",
   325 => x"ff135372",
   326 => x"ffb938a0",
   327 => x"80959451",
   328 => x"a080819b",
   329 => x"2da08087",
   330 => x"b22da080",
   331 => x"99a408a0",
   332 => x"809ac40c",
   333 => x"a08099a4",
   334 => x"08802e8b",
   335 => x"38a08095",
   336 => x"b051a080",
   337 => x"819b2da0",
   338 => x"8095c451",
   339 => x"a080819b",
   340 => x"2d815287",
   341 => x"fc80d051",
   342 => x"a08084fd",
   343 => x"2d81ff0b",
   344 => x"c80cc408",
   345 => x"708f2a70",
   346 => x"81065151",
   347 => x"5372f338",
   348 => x"72c40c81",
   349 => x"ff0bc80c",
   350 => x"a08095d4",
   351 => x"51a08081",
   352 => x"9b2d8153",
   353 => x"72a08099",
   354 => x"a40c028c",
   355 => x"050d0480",
   356 => x"0ba08099",
   357 => x"a40c0402",
   358 => x"e0050d79",
   359 => x"7b575780",
   360 => x"58c40870",
   361 => x"8f2a7081",
   362 => x"06515154",
   363 => x"73f33882",
   364 => x"810bc40c",
   365 => x"81ff0bc8",
   366 => x"0c765287",
   367 => x"fc80d151",
   368 => x"a08084fd",
   369 => x"2d80dbc6",
   370 => x"df55a080",
   371 => x"99a40880",
   372 => x"2e9838a0",
   373 => x"8099a408",
   374 => x"537652a0",
   375 => x"8095e051",
   376 => x"a0808280",
   377 => x"2da0808c",
   378 => x"b60481ff",
   379 => x"0bc80cc8",
   380 => x"087081ff",
   381 => x"06515473",
   382 => x"81fe2e09",
   383 => x"81069b38",
   384 => x"80ff55cc",
   385 => x"08767084",
   386 => x"05580cff",
   387 => x"15557480",
   388 => x"25f13881",
   389 => x"58a0808c",
   390 => x"a004ff15",
   391 => x"5574cb38",
   392 => x"81ff0bc8",
   393 => x"0cc40870",
   394 => x"8f2a7081",
   395 => x"06515154",
   396 => x"73f33873",
   397 => x"c40c77a0",
   398 => x"8099a40c",
   399 => x"02a0050d",
   400 => x"0402f405",
   401 => x"0d747088",
   402 => x"2a83fe80",
   403 => x"06707298",
   404 => x"2a077288",
   405 => x"2b87fc80",
   406 => x"80067398",
   407 => x"2b81f00a",
   408 => x"06717307",
   409 => x"07a08099",
   410 => x"a40c5651",
   411 => x"5351028c",
   412 => x"050d0402",
   413 => x"f4050d02",
   414 => x"92052270",
   415 => x"882a7188",
   416 => x"2b077083",
   417 => x"ffff06a0",
   418 => x"8099a40c",
   419 => x"5252028c",
   420 => x"050d0402",
   421 => x"f8050d73",
   422 => x"70902b71",
   423 => x"902a07a0",
   424 => x"8099a40c",
   425 => x"52028805",
   426 => x"0d0402f4",
   427 => x"050d7476",
   428 => x"52538071",
   429 => x"25903870",
   430 => x"52727084",
   431 => x"055408ff",
   432 => x"13535171",
   433 => x"f438028c",
   434 => x"050d0402",
   435 => x"d8050d7b",
   436 => x"7d5b5681",
   437 => x"0ba08096",
   438 => x"80595783",
   439 => x"59770876",
   440 => x"0c750878",
   441 => x"08565473",
   442 => x"752e9238",
   443 => x"75085374",
   444 => x"52a08096",
   445 => x"9051a080",
   446 => x"82802d80",
   447 => x"57795275",
   448 => x"51a0808d",
   449 => x"aa2d7508",
   450 => x"5473752e",
   451 => x"92387508",
   452 => x"537452a0",
   453 => x"8096d051",
   454 => x"a0808280",
   455 => x"2d8057ff",
   456 => x"19841959",
   457 => x"59788025",
   458 => x"ffb33876",
   459 => x"a08099a4",
   460 => x"0c02a805",
   461 => x"0d0402c8",
   462 => x"050d7f5c",
   463 => x"800ba080",
   464 => x"9790525b",
   465 => x"a0808280",
   466 => x"2d80e1b3",
   467 => x"578e5d76",
   468 => x"598fffff",
   469 => x"5a76bfff",
   470 => x"ff067710",
   471 => x"70962a70",
   472 => x"81065157",
   473 => x"58587480",
   474 => x"2e853876",
   475 => x"81075776",
   476 => x"952a7081",
   477 => x"06515574",
   478 => x"802e8538",
   479 => x"76813257",
   480 => x"76bfffff",
   481 => x"06788429",
   482 => x"1d79710c",
   483 => x"56708429",
   484 => x"1d56750c",
   485 => x"76107096",
   486 => x"2a708106",
   487 => x"51565774",
   488 => x"802e8538",
   489 => x"76810757",
   490 => x"76952a70",
   491 => x"81065155",
   492 => x"74802e85",
   493 => x"38768132",
   494 => x"57ff1a5a",
   495 => x"798025ff",
   496 => x"94387857",
   497 => x"8fffff5a",
   498 => x"76bfffff",
   499 => x"06771070",
   500 => x"962a7081",
   501 => x"06515758",
   502 => x"5674802e",
   503 => x"85387681",
   504 => x"07577695",
   505 => x"2a708106",
   506 => x"51557480",
   507 => x"2e853876",
   508 => x"81325776",
   509 => x"bfffff06",
   510 => x"7684291d",
   511 => x"7008575a",
   512 => x"5874762e",
   513 => x"a738807b",
   514 => x"53a08097",
   515 => x"a4525ea0",
   516 => x"8082802d",
   517 => x"78085475",
   518 => x"537552a0",
   519 => x"8097b851",
   520 => x"a0808280",
   521 => x"2d7d5ba0",
   522 => x"8090af04",
   523 => x"811b5b77",
   524 => x"84291c70",
   525 => x"08565674",
   526 => x"782ea738",
   527 => x"807b53a0",
   528 => x"8097a452",
   529 => x"5ea08082",
   530 => x"802d7508",
   531 => x"54775377",
   532 => x"52a08097",
   533 => x"b851a080",
   534 => x"82802d7d",
   535 => x"5ba08090",
   536 => x"e504811b",
   537 => x"5b761070",
   538 => x"962a7081",
   539 => x"06515657",
   540 => x"74802e85",
   541 => x"38768107",
   542 => x"5776952a",
   543 => x"70810651",
   544 => x"5574802e",
   545 => x"85387681",
   546 => x"3257ff1a",
   547 => x"5a798025",
   548 => x"feb638ff",
   549 => x"1d5d7cfd",
   550 => x"b6387da0",
   551 => x"8099a40c",
   552 => x"02b8050d",
   553 => x"0402cc05",
   554 => x"0d7e5b81",
   555 => x"5c805a80",
   556 => x"c07c585d",
   557 => x"85ada989",
   558 => x"bb7b0c7b",
   559 => x"58815697",
   560 => x"55767607",
   561 => x"822b7b11",
   562 => x"515485ad",
   563 => x"a989bb74",
   564 => x"0c7510ff",
   565 => x"16565674",
   566 => x"8025e638",
   567 => x"76108119",
   568 => x"59579878",
   569 => x"25d7387f",
   570 => x"527a51a0",
   571 => x"808daa2d",
   572 => x"8157ff87",
   573 => x"87a5c37b",
   574 => x"0c975880",
   575 => x"77822b7c",
   576 => x"11700857",
   577 => x"575a5673",
   578 => x"ff8787a5",
   579 => x"c32e0981",
   580 => x"068c3875",
   581 => x"7a78075b",
   582 => x"5ca08092",
   583 => x"bb047408",
   584 => x"547385ad",
   585 => x"a989bb2e",
   586 => x"92387575",
   587 => x"08547953",
   588 => x"a08097e0",
   589 => x"525ca080",
   590 => x"82802d76",
   591 => x"10ff1959",
   592 => x"57778025",
   593 => x"ffb53879",
   594 => x"802e9e38",
   595 => x"79822b52",
   596 => x"a0809880",
   597 => x"51a08082",
   598 => x"802d7910",
   599 => x"87fffffe",
   600 => x"067d812c",
   601 => x"5e5a79f2",
   602 => x"387c52a0",
   603 => x"80989851",
   604 => x"a0808280",
   605 => x"2d7ba080",
   606 => x"99a40c02",
   607 => x"b4050d04",
   608 => x"02f8050d",
   609 => x"88bd0bff",
   610 => x"880ca080",
   611 => x"528051a0",
   612 => x"808dcb2d",
   613 => x"a08099a4",
   614 => x"08802e8b",
   615 => x"38a08098",
   616 => x"d451a080",
   617 => x"82802da0",
   618 => x"80528051",
   619 => x"a08091a5",
   620 => x"2da08099",
   621 => x"a408802e",
   622 => x"8b38a080",
   623 => x"98f851a0",
   624 => x"8082802d",
   625 => x"8051a080",
   626 => x"8eb62da0",
   627 => x"8099a408",
   628 => x"802e8b38",
   629 => x"a0809990",
   630 => x"51a08082",
   631 => x"802d800b",
   632 => x"a08099a4",
   633 => x"0c028805",
   634 => x"0d040000",
   635 => x"00ffffff",
   636 => x"ff00ffff",
   637 => x"ffff00ff",
   638 => x"ffffff00",
   639 => x"30313233",
   640 => x"34353637",
   641 => x"38394142",
   642 => x"43444546",
   643 => x"00000000",
   644 => x"53444843",
   645 => x"20496e69",
   646 => x"7469616c",
   647 => x"697a6174",
   648 => x"696f6e20",
   649 => x"6572726f",
   650 => x"72210a00",
   651 => x"434d4435",
   652 => x"38202564",
   653 => x"0a202000",
   654 => x"434d4435",
   655 => x"385f3220",
   656 => x"25640a20",
   657 => x"20000000",
   658 => x"44657465",
   659 => x"726d696e",
   660 => x"65642053",
   661 => x"44484320",
   662 => x"73746174",
   663 => x"75730a00",
   664 => x"53656e74",
   665 => x"20726573",
   666 => x"65742063",
   667 => x"6f6d6d61",
   668 => x"6e640a00",
   669 => x"53442063",
   670 => x"61726420",
   671 => x"696e6974",
   672 => x"69616c69",
   673 => x"7a617469",
   674 => x"6f6e2065",
   675 => x"72726f72",
   676 => x"210a0000",
   677 => x"43617264",
   678 => x"20726573",
   679 => x"706f6e64",
   680 => x"65642074",
   681 => x"6f207265",
   682 => x"7365740a",
   683 => x"00000000",
   684 => x"53444843",
   685 => x"20636172",
   686 => x"64206465",
   687 => x"74656374",
   688 => x"65640a00",
   689 => x"53656e64",
   690 => x"696e6720",
   691 => x"636d6431",
   692 => x"360a0000",
   693 => x"496e6974",
   694 => x"20646f6e",
   695 => x"650a0000",
   696 => x"52656164",
   697 => x"20636f6d",
   698 => x"6d616e64",
   699 => x"20666169",
   700 => x"6c656420",
   701 => x"61742025",
   702 => x"64202825",
   703 => x"64290a00",
   704 => x"00000000",
   705 => x"55555555",
   706 => x"aaaaaaaa",
   707 => x"ffffffff",
   708 => x"53616e69",
   709 => x"74792063",
   710 => x"6865636b",
   711 => x"20666169",
   712 => x"6c656420",
   713 => x"28626566",
   714 => x"6f726520",
   715 => x"63616368",
   716 => x"65207265",
   717 => x"66726573",
   718 => x"6829206f",
   719 => x"6e203078",
   720 => x"25642028",
   721 => x"676f7420",
   722 => x"30782564",
   723 => x"290a0000",
   724 => x"53616e69",
   725 => x"74792063",
   726 => x"6865636b",
   727 => x"20666169",
   728 => x"6c656420",
   729 => x"28616674",
   730 => x"65722063",
   731 => x"61636865",
   732 => x"20726566",
   733 => x"72657368",
   734 => x"29206f6e",
   735 => x"20307825",
   736 => x"64202867",
   737 => x"6f742030",
   738 => x"78256429",
   739 => x"0a000000",
   740 => x"43686563",
   741 => x"6b696e67",
   742 => x"206d656d",
   743 => x"6f72792e",
   744 => x"2e2e0a00",
   745 => x"30782564",
   746 => x"20676f6f",
   747 => x"64207265",
   748 => x"6164732c",
   749 => x"20000000",
   750 => x"4572726f",
   751 => x"72206174",
   752 => x"20307825",
   753 => x"642c2065",
   754 => x"78706563",
   755 => x"74656420",
   756 => x"30782564",
   757 => x"2c20676f",
   758 => x"74203078",
   759 => x"25640a00",
   760 => x"42616420",
   761 => x"64617461",
   762 => x"20666f75",
   763 => x"6e642061",
   764 => x"74203078",
   765 => x"25642028",
   766 => x"30782564",
   767 => x"290a0000",
   768 => x"416c6961",
   769 => x"73657320",
   770 => x"666f756e",
   771 => x"64206174",
   772 => x"20307825",
   773 => x"640a0000",
   774 => x"53445241",
   775 => x"4d207369",
   776 => x"7a652028",
   777 => x"61737375",
   778 => x"6d696e67",
   779 => x"206e6f20",
   780 => x"61646472",
   781 => x"65737320",
   782 => x"6661756c",
   783 => x"74732920",
   784 => x"69732030",
   785 => x"78256420",
   786 => x"6d656761",
   787 => x"62797465",
   788 => x"730a0000",
   789 => x"46697273",
   790 => x"74207374",
   791 => x"61676520",
   792 => x"73616e69",
   793 => x"74792063",
   794 => x"6865636b",
   795 => x"20706173",
   796 => x"7365642e",
   797 => x"0a000000",
   798 => x"41646472",
   799 => x"65737320",
   800 => x"63686563",
   801 => x"6b207061",
   802 => x"73736564",
   803 => x"2e0a0000",
   804 => x"4c465352",
   805 => x"20636865",
   806 => x"636b2070",
   807 => x"61737365",
   808 => x"642e0a00",
	others => x"00000000"
);

begin

process (clk)
begin
	if (clk'event and clk = '1') then
		if (from_zpu.memAWriteEnable = '1') and (from_zpu.memBWriteEnable = '1') and (from_zpu.memAAddr=from_zpu.memBAddr) and (from_zpu.memAWrite/=from_zpu.memBWrite) then
			report "write collision" severity failure;
		end if;
	
		if (from_zpu.memAWriteEnable = '1') then
			ram(to_integer(unsigned(from_zpu.memAAddr))) := from_zpu.memAWrite;
			to_zpu.memARead <= from_zpu.memAWrite;
		else
			to_zpu.memARead <= ram(to_integer(unsigned(from_zpu.memAAddr)));
		end if;
	end if;
end process;

process (clk)
begin
	if (clk'event and clk = '1') then
		if (from_zpu.memBWriteEnable = '1') then
			ram(to_integer(unsigned(from_zpu.memBAddr))) := from_zpu.memBWrite;
			to_zpu.memBRead <= from_zpu.memBWrite;
		else
			to_zpu.memBRead <= ram(to_integer(unsigned(from_zpu.memBAddr)));
		end if;
	end if;
end process;


end arch;

