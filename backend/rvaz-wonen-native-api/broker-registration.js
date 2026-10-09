(()=>{
 'use strict';
 const form=document.querySelector('input[name="rvaz_member_register"]')?.form;
 if(!form)return;
 const company=form.querySelector('#rvaz-company-field');
 const update=()=>{const type=form.querySelector('input[name="account_type"]:checked')?.value;if(company)company.style.display=['business','makelaar'].includes(type)?'block':'none';};
 document.addEventListener('change',event=>{if(event.target.form===form&&event.target.name==='account_type')update();});
 if(new URLSearchParams(location.search).get('type')==='makelaar'){
  const choice=form.querySelector('input[value="makelaar"]');if(choice)choice.checked=true;
 }
 update();
})();
