(()=>{
 'use strict';
 const update=form=>{const transaction=form.querySelector('select[name="transactie"]');if(!transaction)return;const rent=transaction.value==='Huur';for(const key of ['borg','contractduur','inkomenseisen','prijstype']){const field=form.querySelector(`[name="${key}"]`),label=field?.closest('label');if(!label)continue;const hidden=key==='prijstype'?rent:!rent;if(label.hasAttribute('data-rvaz-housing-hidden')!==hidden)label.toggleAttribute('data-rvaz-housing-hidden',hidden);}};
 const scan=()=>document.querySelectorAll('form').forEach(form=>{if(!form.querySelector('select[name="transactie"]'))return;if(!form.dataset.rvazHousingBound){form.dataset.rvazHousingBound='1';form.addEventListener('change',event=>{if(event.target.name==='transactie')update(form);});}update(form);});
 scan();new MutationObserver(scan).observe(document.body,{childList:true,subtree:true});
})();
