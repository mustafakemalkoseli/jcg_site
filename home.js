(function(){
 var h=document.querySelector('.hero2'),rm=matchMedia('(prefers-reduced-motion: reduce)').matches;
 if(h&&!rm&&matchMedia('(pointer:fine)').matches){h.addEventListener('pointermove',function(e){var r=h.getBoundingClientRect();
  h.style.setProperty('--mx',((e.clientX-r.left)/r.width-.5)*2);h.style.setProperty('--my',((e.clientY-r.top)/r.height-.5)*2);});}
 document.querySelectorAll('.gal').forEach(function(g){
  var imgs=g.querySelectorAll('.main img'),bs=g.querySelectorAll('.thumbs button'),cur=0,timer=null;
  function show(i){cur=i;imgs.forEach(function(m,k){m.classList.toggle('on',k===i)});bs.forEach(function(b,k){b.setAttribute('aria-pressed',k===i?'true':'false')});}
  function auto(){if(rm)return;clearInterval(timer);timer=setInterval(function(){show((cur+1)%imgs.length)},4200);}
  bs.forEach(function(b,k){b.addEventListener('click',function(){show(k);auto();});});auto();
 });
 var els=document.querySelectorAll('.rv');
 if(!('IntersectionObserver' in window)||rm){els.forEach(function(e){e.classList.add('in')});return;}
 var io=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){e.target.classList.add('in');io.unobserve(e.target);}})},{threshold:.12,rootMargin:'0px 0px -6% 0px'});
 els.forEach(function(e){io.observe(e)});
})();
