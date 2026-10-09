<?php
require dirname(__DIR__,2).'/website/rvaz-wonen-store-payments/includes/apple.php';
function reject($jws){try{RVAZ_Store_Apple::verify($jws);}catch(Throwable $e){return;}throw new RuntimeException('Unsigned/untrusted receipt accepted');}
function enc($value){return rtrim(strtr(base64_encode(json_encode($value)),'+/','-_'),'=');}
foreach(['','fake-receipt','a.b.c',enc(['alg'=>'none']).'.'.enc(['transactionId'=>'free']).'.AA',enc(['alg'=>'HS256','x5c'=>['ZmFrZQ==','ZmFrZQ==']]).'.e30.AA',enc(['alg'=>'ES256','x5c'=>['ZmFrZQ==','ZmFrZQ==']]).'.e30.AA'] as $jws)reject($jws);
$integer=RVAZ_Store_Apple::integer(str_repeat("\0",32));if($integer!=="\x02\x01\0")throw new RuntimeException('ECDSA integer zero');
$integer=RVAZ_Store_Apple::integer("\x80".str_repeat("\0",31));if(substr($integer,0,4)!=="\x02\x21\0\x80")throw new RuntimeException('ECDSA integer sign');
echo "Apple rejects unsigned, malformed and untrusted receipts; ECDSA conversion passed.\n";
