(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,584282,e=>{"use strict";var t=e.i(253332),o=e.i(111092),n=e.i(649924),r=e.i(278928),i=e.i(529025),s=e.i(484631),a=t.Node.create({name:"endnoteItem",group:"block",content:"block+",isolating:!0,defining:!0,addAttributes:()=>({noteId:{default:null,parseHTML:e=>e.getAttribute("data-note-id"),renderHTML:e=>({"data-note-id":e.noteId})}}),parseHTML:()=>[{tag:"div.tiptap-endnote-item[data-note-id]"}],renderHTML:({HTMLAttributes:e})=>["div",{...e,class:"tiptap-endnote-item"},0]}),l="endnoteReference";function d(e){let t=[];return e.descendants((e,o)=>{if(e.type.name!==l)return;let n=e.attrs.noteId;"string"==typeof n&&""!==n&&t.push({noteId:n,pos:o})}),t}function h(e){let t={},o=1;for(let n of e)void 0===t[n.noteId]&&(t[n.noteId]=o,o+=1);return t}function p(e){let t=[];for(let o of e.references)e.knownIds.includes(o.noteId)&&!t.includes(o.noteId)&&t.push(o.noteId);for(let o of e.knownIds)t.includes(o)||t.push(o);return t}function u(){let e=Date.now().toString(36),t=Math.random().toString(36).substring(2,9);return`fn-${e}-${t}`}function g(){let e=Date.now().toString(36),t=Math.random().toString(36).substring(2,9);return`en-${e}-${t}`}var c=[[1e3,"m"],[900,"cm"],[500,"d"],[400,"cd"],[100,"c"],[90,"xc"],[50,"l"],[40,"xl"],[10,"x"],[9,"ix"],[5,"v"],[4,"iv"],[1,"i"]];function f(e){if(!Number.isFinite(e)||e<1)return String(e);let t=Math.floor(e),o="";for(let[e,n]of c)for(;t>=e;)o+=n,t-=e;return o}var m=null,v=t.Node.create({name:"endnoteReference",inline:!0,group:"inline",atom:!0,selectable:!0,addAttributes:()=>({noteId:{default:null,parseHTML:e=>e.getAttribute("data-note-id"),renderHTML:e=>({"data-note-id":e.noteId})}}),parseHTML:()=>[{tag:"sup.tiptap-endnote-ref[data-note-id]",priority:60}],renderHTML:({HTMLAttributes:e})=>["sup",{...e,class:"tiptap-endnote-ref"}],addProseMirrorPlugins:()=>[new o.Plugin({key:new o.PluginKey("endnote-reference-numbers"),state:{init:(e,t)=>b(t.doc),apply:(e,t)=>e.docChanged?b(e.doc):t},props:{decorations(e){return this.getState(e)}},appendTransaction:(e,t,o)=>e.some(e=>e.docChanged)?function(e,t){let o,n,r=(o=new Set,n=[],t.descendants((e,t)=>{if(e.type.name!==l)return;let r=e.attrs.noteId;"string"!=typeof r||""===r?n.push({pos:t,originalNoteId:null}):o.has(r)?n.push({pos:t,originalNoteId:r}):o.add(r)}),n);if(0===r.length)return null;for(let t of r){let o=g(),n=e.doc.nodeAt(t.pos);n&&(e.setNodeMarkup(t.pos,void 0,{...n.attrs,noteId:o}),t.originalNoteId&&(null==m||m(t.originalNoteId,o)))}return e}(o.tr,o.doc):null})]});function b(e){let t=d(e);if(0===t.length)return n.DecorationSet.empty;let o=h(t),r=t.map(e=>n.Decoration.node(e.pos,e.pos+1,{"data-endnote-number":f(o[e.noteId])}));return n.DecorationSet.create(e,r)}var y=t.Node.create({name:"footnoteItem",group:"block",content:"block+",isolating:!0,defining:!0,addAttributes:()=>({noteId:{default:null,parseHTML:e=>e.getAttribute("data-note-id"),renderHTML:e=>({"data-note-id":e.noteId})}}),parseHTML:()=>[{tag:"div.tiptap-footnote-item[data-note-id]"}],renderHTML:({HTMLAttributes:e})=>["div",{...e,class:"tiptap-footnote-item"},0]}),C="footnoteReference";function w(e){let t=[];return e.descendants((e,o)=>{if(e.type.name!==C)return;let n=e.attrs.noteId;"string"==typeof n&&""!==n&&t.push({noteId:n,pos:o})}),t}function E(e){let t={},o=1;for(let n of e)void 0===t[n.noteId]&&(t[n.noteId]=o,o+=1);return t}function H(e){let t=[];for(let o of e.references)e.knownIds.includes(o.noteId)&&!t.includes(o.noteId)&&t.push(o.noteId);for(let o of e.knownIds)t.includes(o)||t.push(o);return t}var T=null,M=t.Node.create({name:"footnoteReference",inline:!0,group:"inline",atom:!0,selectable:!0,addAttributes:()=>({noteId:{default:null,parseHTML:e=>e.getAttribute("data-note-id"),renderHTML:e=>({"data-note-id":e.noteId})}}),parseHTML:()=>[{tag:"sup.tiptap-footnote-ref[data-note-id]",priority:60}],renderHTML:({HTMLAttributes:e})=>["sup",{...e,class:"tiptap-footnote-ref"}],addProseMirrorPlugins:()=>[new o.Plugin({key:new o.PluginKey("footnote-reference-numbers"),state:{init:(e,t)=>O(t.doc),apply:(e,t)=>e.docChanged?O(e.doc):t},props:{decorations(e){return this.getState(e)}},appendTransaction:(e,t,o)=>e.some(e=>e.docChanged)?function(e,t){let o,n,r=(o=new Set,n=[],t.descendants((e,t)=>{if(e.type.name!==C)return;let r=e.attrs.noteId;"string"!=typeof r||""===r?n.push({pos:t,originalNoteId:null}):o.has(r)?n.push({pos:t,originalNoteId:r}):o.add(r)}),n);if(0===r.length)return null;for(let t of r){let o=u(),n=e.doc.nodeAt(t.pos);n&&(e.setNodeMarkup(t.pos,void 0,{...n.attrs,noteId:o}),t.originalNoteId&&(null==T||T(t.originalNoteId,o)))}return e}(o.tr,o.doc):null})]});function O(e){let t=w(e);if(0===t.length)return n.DecorationSet.empty;let o=E(t),r=t.map(e=>n.Decoration.node(e.pos,e.pos+1,{"data-footnote-number":String(o[e.noteId])}));return n.DecorationSet.create(e,r)}var x=class{constructor(){this.entries=new Map,this.updateListeners=new Map,this.persistentUpdateListeners=new Map,this.persistentHeightListeners=new Map,this.offscreenHost=null}setOffscreenHost(e){if(this.offscreenHost===e)return;let t=this.offscreenHost;for(let o of(this.offscreenHost=e,this.entries.values()))o.container.parentElement===t&&(e?e.appendChild(o.container):o.container.remove())}ensure(e,o){var n,r;let i=this.entries.get(e);if(i)return i.editor;let s=document.createElement("div");s.dataset.headerFooterSubType=e,null==(n=o.setupContainer)||n.call(o,s),this.offscreenHost&&this.offscreenHost.appendChild(s);let a=new t.Editor({element:s,extensions:o.extensions,content:o.isCollaborative?void 0:null!=(r=o.initialContent)?r:{type:"doc",content:[{type:"paragraph"}]},onUpdate:()=>{var t,o;null==(t=this.persistentUpdateListeners.get(e))||t(),null==(o=this.updateListeners.get(e))||o()}}),l={editor:a,container:s,resizeObserver:null,observedElement:null,lastContentHeight:0};return this.entries.set(e,l),this.attachResizeObserverIfNeeded(e,l),a}mountInto(e,t){let o=this.entries.get(t);o&&o.container.parentElement!==e&&e.appendChild(o.container)}unmount(e){let t=this.entries.get(e);t&&(this.offscreenHost?this.offscreenHost.appendChild(t.container):t.container.remove())}setUpdateListener(e,t){this.updateListeners.set(e,t)}setPersistentUpdateListener(e,t){this.persistentUpdateListeners.set(e,t)}setPersistentHeightListener(e,t){this.persistentHeightListeners.set(e,t);let o=this.entries.get(e);o&&this.attachResizeObserverIfNeeded(e,o)}getEditor(e){var t,o;return null!=(o=null==(t=this.entries.get(e))?void 0:t.editor)?o:null}destroyAll(){var e,t;for(let t of this.entries.values())null==(e=t.resizeObserver)||e.disconnect(),t.editor.destroy(),t.container.remove();this.entries.clear(),this.updateListeners.clear(),this.persistentUpdateListeners.clear(),this.persistentHeightListeners.clear(),null!=(t=this.offscreenHost)&&t.parentElement}attachResizeObserverIfNeeded(e,t){var o,n;if(!this.persistentHeightListeners.get(e)){null==(o=t.resizeObserver)||o.disconnect(),t.resizeObserver=null,t.observedElement=null;return}let r=t.container.querySelector(".ProseMirror");r?t.observedElement===r&&t.resizeObserver||(null==(n=t.resizeObserver)||n.disconnect(),t.observedElement=r,t.resizeObserver=new ResizeObserver(()=>{let o=this.persistentHeightListeners.get(e),n=t.observedElement;if(!(null!=n&&n.lastElementChild))return;let r=n.getBoundingClientRect(),i=n.lastElementChild.getBoundingClientRect().bottom-r.top;i>0&&(t.lastContentHeight=i,null==o||o(i))}),t.resizeObserver.observe(r)):queueMicrotask(()=>{let o=this.entries.get(e);o&&o===t&&this.attachResizeObserverIfNeeded(e,t)})}getLastContentHeight(e){var t,o;return null!=(o=null==(t=this.entries.get(e))?void 0:t.lastContentHeight)?o:0}},P="endnote-numbers",F=new o.PluginKey("endnote-story-numbers"),k=t.Extension.create({name:"endnoteStoryNumbers",addProseMirrorPlugins:()=>[new o.Plugin({key:F,state:{init:()=>null,apply:(e,t)=>{let o=e.getMeta(P);return void 0===o?t:o}},props:{decorations(e){let t=F.getState(e);if(!t)return n.DecorationSet.empty;let o=[];return e.doc.forEach((e,r)=>{if("endnoteItem"!==e.type.name)return;let i=e.attrs.noteId;if("string"!=typeof i)return;let s=t[i];void 0!==s&&o.push(n.Decoration.node(r,r+e.nodeSize,{"data-endnote-number":f(s),style:`order: ${s}`}))}),n.DecorationSet.create(e.doc,o)}}})]}),S=`<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M13.2427 4.75736L4.75739 13.2426" stroke="#0F1214" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M13.2427 13.2426L4.7574 4.75736" stroke="#0F1214" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`,N="default",L=class e{constructor(){this.overlay=null,this.editorContainer=null,this.pool=new x,this.measurementEditor=null,this.measurementContainer=null,this.measurementExtensions=[s.ConvertKit],this.storyExtensions=[s.ConvertKit],this.isCollaborative=!1,this.offscreenHost=null,this.isOpen=!1,this.currentTarget=null,this.currentOwnerRoot=null,this.onClose=null,this.resizeObserver=null,this.toolbar=null,this.documentDblClickHandler=null,this.onDblClickOutsidePreventClose=null,this.currentZoom=1,this.initialScrollY=0,this.autoUpdateCleanup=null,this.updatePositionFn=null,this.createOverlay()}static getInstance(){return e.instance||(e.instance=new e),e.instance}static destroy(){e.instance&&(e.instance.cleanup(),e.instance=null)}createOverlay(){this.overlay=document.createElement("div"),this.overlay.className="tiptap-endnotes-editor-overlay",this.overlay.style.cssText=`
      position: absolute;
      display: none;
      z-index: 1000;
      background: white;
      box-sizing: border-box;
    `,this.editorContainer=document.createElement("div"),this.editorContainer.className="tiptap-endnotes-editor-container",this.editorContainer.style.cssText=`
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
    `,this.overlay.appendChild(this.editorContainer),document.body.appendChild(this.overlay),this.ensureMeasurementEditor(),this.overlay.addEventListener("keydown",e=>{"Escape"===e.key&&(e.preventDefault(),this.hide()),e.stopPropagation()},{capture:!0});let e=e=>e.stopPropagation();this.overlay.addEventListener("keyup",e,{capture:!0}),this.overlay.addEventListener("keypress",e,{capture:!0}),this.overlay.addEventListener("mousedown",e),this.overlay.addEventListener("click",e)}ensureMeasurementEditor(){var e;this.measurementContainer||(this.measurementContainer=document.createElement("div"),this.measurementContainer.className="tiptap-endnotes-editor-measurement",this.measurementContainer.style.cssText=`
        position: absolute;
        left: -10000px;
        top: 0;
        visibility: hidden;
        pointer-events: none;
      `,document.body.appendChild(this.measurementContainer)),null==(e=this.measurementEditor)||e.destroy(),this.measurementEditor=new t.Editor({element:this.measurementContainer,extensions:this.measurementExtensions,content:{type:"doc",content:[{type:"paragraph"}]}})}configure(e){this.pool.destroyAll(),this.storyExtensions=e.storyExtensions.length>0?e.storyExtensions:[s.ConvertKit],this.measurementExtensions=e.measurementExtensions.length>0?e.measurementExtensions:[s.ConvertKit],this.isCollaborative=e.isCollaborative,this.ensureMeasurementEditor(),e.offscreenContentWidth>0&&(this.ensureOffscreenHost(e.offscreenContentWidth),this.pool.setOffscreenHost(this.offscreenHost))}ensureOffscreenHost(e){this.offscreenHost||(this.offscreenHost=document.createElement("div"),this.offscreenHost.className="tiptap-endnotes-editor-offscreen",document.body.appendChild(this.offscreenHost)),this.offscreenHost.style.cssText=`
      position: fixed;
      left: -10000px;
      top: 0;
      visibility: hidden;
      pointer-events: none;
      width: ${e}px;
      box-sizing: border-box;
    `}eagerlyCreate(){this.ensureStoryEditor()}ensureStoryEditor(){return this.pool.ensure(N,{extensions:this.storyExtensions,isCollaborative:this.isCollaborative,setupContainer:e=>{e.style.cssText=`
          width: 100%;
        `}})}setPersistentUpdateListener(e){this.pool.setPersistentUpdateListener(N,e)}show(e,t){var o,n,i;if(!this.overlay||!this.editorContainer)return;this.isOpen=!0,this.currentTarget=e,this.currentOwnerRoot=t.ownerRoot||null,this.currentZoom=null!=(o=t.zoom)?o:1,this.onClose=t.onClose||null,this.onDblClickOutsidePreventClose=t.onDblClickOutsidePreventClose||null;let s=this.ensureStoryEditor();this.ensureStoryItems(t.noteIds,t.numbers),this.applyNumbers(t.numbers),this.pool.mountInto(this.editorContainer,N);let a=window.getComputedStyle(e),l=this.editorContainer.querySelector(".ProseMirror");l instanceof HTMLElement&&(l.style.fontFamily=a.fontFamily,l.style.fontSize=a.fontSize,l.style.lineHeight=a.lineHeight,l.style.color=a.color),this.overlay.classList.toggle("tiptap-endnotes-with-separator",!1!==t.separator),this.initialScrollY=window.scrollY;let d=e.getBoundingClientRect();this.overlay.style.display="block",this.overlay.style.transform="none",this.overlay.style.height=`${d.height}px`,this.overlay.style.padding="0",this.editorContainer.style.zoom=String(this.currentZoom);let h=()=>{let e=this.getAreaElement();if(!this.overlay||!e)return;this.currentTarget=e;let t=e.getBoundingClientRect(),o=window.getComputedStyle(e),n=parseFloat(o.paddingLeft)||0,r=parseFloat(o.paddingRight)||0,i=this.currentZoom,s=t.top+window.scrollY;this.overlay.style.left=`${t.left+window.scrollX+n*i}px`,this.overlay.style.top=`${s}px`,this.overlay.style.width=`${t.width-(n+r)*i}px`,this.recomputeOverlayHeight()};this.updatePositionFn=h,h(),this.autoUpdateCleanup=(0,r.autoUpdate)({getBoundingClientRect:()=>{let e=this.getAreaElement();return e?e.getBoundingClientRect():{x:0,y:0,top:0,left:0,bottom:0,right:0,width:0,height:0}}},this.overlay,h,{elementResize:!0,layoutShift:!0,ancestorScroll:!0,ancestorResize:!0,animationFrame:!0});let p=null!=(i=null!=(n=t.focusNoteId)?n:t.noteIds[t.noteIds.length-1])?i:void 0;setTimeout(()=>{void 0!==p?this.focusEndnote(p):s.commands.focus("end")},0),this.createToolbar(),this.setupResizeObserver(),this.setupDocumentDblClickHandler()}applyNumbers(e){let t=this.pool.getEditor(N);t&&t.view.dispatch(t.state.tr.setMeta(P,e))}setupDocumentDblClickHandler(){this.removeDocumentDblClickHandler(),this.documentDblClickHandler=e=>{if(!(!this.overlay||"none"===this.overlay.style.display)&&!this.overlay.contains(e.target)){if(this.onDblClickOutsidePreventClose)try{if(this.onDblClickOutsidePreventClose(e))return}catch(e){console.error("[Pages] Error in onDblClickOutsidePreventClose callback:",e)}this.hide()}},document.addEventListener("dblclick",this.documentDblClickHandler)}removeDocumentDblClickHandler(){this.documentDblClickHandler&&(document.removeEventListener("dblclick",this.documentDblClickHandler),this.documentDblClickHandler=null)}createToolbar(){var e,t;if(this.removeToolbar(),!this.overlay||!this.currentTarget)return;let o=this.currentZoom,n=window.getComputedStyle(this.currentTarget),r=this.currentOwnerRoot?window.getComputedStyle(this.currentOwnerRoot):null,i=parseFloat(n.paddingLeft)||parseFloat(null!=(e=null==r?void 0:r.paddingLeft)?e:"0")||0,s=parseFloat(n.paddingRight)||parseFloat(null!=(t=null==r?void 0:r.paddingRight)?t:"0")||0,a=Math.max(0,i*o-1),l=Math.max(0,s*o-1);this.toolbar=document.createElement("div"),this.toolbar.className="tiptap-endnotes-edit-toolbar",this.toolbar.style.left=`-${a}px`,this.toolbar.style.right=`-${l}px`;let d=document.createElement("span");d.className="tiptap-endnotes-edit-label",d.textContent="Endnotes";let h=document.createElement("div");h.className="tiptap-endnotes-edit-actions";let p=document.createElement("button");p.className="tiptap-endnotes-edit-close",p.innerHTML=S,p.type="button",p.onclick=e=>{e.preventDefault(),e.stopPropagation(),this.hide()},h.appendChild(p),this.toolbar.appendChild(d),this.toolbar.appendChild(h),this.overlay.appendChild(this.toolbar)}removeToolbar(){var e;null==(e=this.toolbar)||e.remove(),this.toolbar=null}setupResizeObserver(){var e;if(!this.editorContainer)return;let t=this.editorContainer.querySelector(".ProseMirror");t instanceof HTMLElement&&(null==(e=this.resizeObserver)||e.disconnect(),this.resizeObserver=new ResizeObserver(()=>{this.handleContentResize()}),this.resizeObserver.observe(t))}handleContentResize(){this.recomputeOverlayHeight(),window.scrollTo(0,this.initialScrollY)}recomputeOverlayHeight(){if(!this.overlay||!this.editorContainer)return;let e=this.editorContainer.querySelector(".ProseMirror");if(!(e instanceof HTMLElement)||!e.lastElementChild)return;let t=e.getBoundingClientRect(),o=t.top;for(let t of e.children){let e=t.getBoundingClientRect().bottom;e>o&&(o=e)}let n=o-t.top,r=this.isOpen?this.getAreaElement():null,i=Math.max(r?r.getBoundingClientRect().height:0,n);Math.abs(i-(Number.parseFloat(this.overlay.style.height)||0))>.5&&(this.overlay.style.height=`${i}px`)}hide(){var e;if(!this.overlay||!this.editorContainer)return;let t=this.isOpen;this.updatePositionFn=null,this.autoUpdateCleanup&&(this.autoUpdateCleanup(),this.autoUpdateCleanup=null),null==(e=this.resizeObserver)||e.disconnect(),this.resizeObserver=null,this.removeToolbar(),this.removeDocumentDblClickHandler(),this.applyNumbers(null),this.pool.unmount(N),this.overlay.style.display="none",this.editorContainer.style.zoom="",t&&this.onClose&&this.onClose(),this.isOpen=!1,this.currentTarget=null,this.currentOwnerRoot=null,this.onClose=null,this.onDblClickOutsidePreventClose=null}getEditor(){return this.pool.getEditor(N)}getStoryNoteIds(){let e=this.pool.getEditor(N);if(!e)return[];let t=[];return e.state.doc.forEach(e=>{let o=e.attrs.noteId;"endnoteItem"===e.type.name&&"string"==typeof o&&t.push(o)}),t}getEndnoteJSONById(e){let t=this.pool.getEditor(N);if(!t)return null;let o=null;return t.state.doc.forEach(t=>{var n;null===o&&"endnoteItem"===t.type.name&&t.attrs.noteId===e&&(o={type:"doc",content:null!=(n=t.content.toJSON())?n:[]})}),o}getEndnoteHTMLById(e){let t=this.getEndnoteJSONById(e);return t?this.normalizeHTML(t):null}setEndnotesContent(e,t){let o=this.pool.getEditor(N);if(!o)return;let n=e.filter(e=>t[e]).map(e=>{var o;return{type:"endnoteItem",attrs:{noteId:e},content:null!=(o=t[e].content)?o:[{type:"paragraph"}]}});o.commands.setContent({type:"doc",content:n})}ensureStoryItems(e,t){var o;let n=new Set(this.getStoryNoteIds());for(let r of e.filter(e=>!n.has(e)).sort((e,o)=>{var n,r;return(null!=(n=t[e])?n:0)-(null!=(r=t[o])?r:0)})){let e=null!=(o=t[r])?o:Number.MAX_SAFE_INTEGER,n=this.getStoryNoteIds().filter(o=>{var n;return(null!=(n=t[o])?n:0)<e}).length;this.insertEndnoteItem(r,n)}}insertEndnoteItem(e,t){var o;let n=this.pool.getEditor(N);if(!n)return;let r=n.schema.nodes.endnoteItem,i=n.schema.nodes.paragraph;if(!r||!i)return;let s=r.create({noteId:e},i.create()),{doc:a}=n.state;if(1===a.childCount&&(null==(o=a.firstChild)?void 0:o.type.name)==="paragraph"&&0===a.firstChild.content.size)return void n.view.dispatch(n.state.tr.replaceWith(0,a.content.size,s));let l=0,d=0;a.forEach((e,o)=>{d<t&&(l=o+e.nodeSize,d+=1)}),n.view.dispatch(n.state.tr.insert(l,s))}cloneEndnote(e,t){let o=this.pool.getEditor(N);if(!o)return;let n=null,r=null;if(o.state.doc.forEach((t,o)=>{if(null===r&&"endnoteItem"===t.type.name&&t.attrs.noteId===e){n=o+t.nodeSize;let e=t.content.toJSON();r=Array.isArray(e)?e:null}}),null===n)return;let s=o.schema.nodes.endnoteItem,a=o.schema.nodes.paragraph;if(!s||!a)return;let l=r?i.Fragment.fromJSON(o.schema,r):i.Fragment.from(a.create()),d=s.create({noteId:t},l);o.view.dispatch(o.state.tr.insert(n,d))}removeOrphanItems(e){let t=this.pool.getEditor(N);if(!t)return!1;let o=[];if(t.state.doc.forEach((t,n)=>{let r=t.attrs.noteId;"endnoteItem"!==t.type.name||"string"!=typeof r||e.has(r)||o.push({from:n,to:n+t.nodeSize})}),0===o.length)return!1;let n=t.state.tr;for(let e of o.reverse())n=n.delete(e.from,e.to);return t.view.dispatch(n),!0}focusEndnote(e){let t=this.pool.getEditor(N);if(!t)return;let o=null;t.state.doc.forEach((t,n)=>{null===o&&"endnoteItem"===t.type.name&&t.attrs.noteId===e&&(o=n+t.nodeSize-2)}),null!==o&&t.commands.focus(o)}normalizeHTML(e){return this.measurementEditor&&("string"!=typeof e||e.trim())?(this.measurementEditor.commands.setContent(e),this.measurementEditor.getHTML()):"<p></p>"}updateZoom(e){var t;this.currentZoom=e,this.editorContainer&&(this.editorContainer.style.zoom=String(e)),null==(t=this.updatePositionFn)||t.call(this),this.isOpen&&this.createToolbar()}isVisible(){var e;return(null==(e=this.overlay)?void 0:e.style.display)!=="none"}getAreaElement(){let e=".tiptap-endnotes",t=this.currentOwnerRoot?this.currentOwnerRoot.querySelector(e):document.querySelector(e);return t instanceof HTMLElement?t:null}cleanup(){var e,t,o,n;this.autoUpdateCleanup&&(this.autoUpdateCleanup(),this.autoUpdateCleanup=null),this.removeDocumentDblClickHandler(),this.pool.destroyAll(),null==(e=this.offscreenHost)||e.remove(),this.offscreenHost=null,null==(t=this.measurementEditor)||t.destroy(),this.measurementEditor=null,null==(o=this.measurementContainer)||o.remove(),this.measurementContainer=null,null==(n=this.overlay)||n.remove(),this.overlay=null,this.editorContainer=null,this.currentOwnerRoot=null}};L.instance=null;var I="tiptap-endnotes-editor-overlay-styles",D=!0;function z(e){return`
    .tiptap-endnotes-editor-overlay .tiptap {
      outline: none;
      min-height: 1em;
      padding: 0;
      margin: 0;
    }

    .tiptap-endnotes-editor-overlay .tiptap p {
      margin: 0;
      padding: 0;
    }

    .tiptap-endnotes-editor-overlay .tiptap:focus {
      outline: none;
    }

    .tiptap-endnotes-editor-overlay .ProseMirror {
      padding: 0 !important;
      margin: 0 !important;
      caret-color: ${e};
      /* Font metrics are inherited from the page's endnotes area (copied
         onto the container in show()) so preview and editor never drift. */
      /* Flex column so items can be sorted by endnote number via the story
         numbers plugin's order decoration. */
      display: flex;
      flex-direction: column;
    }

    /* Word-style separator rule, matching the rendered preview's geometry.
       Top margin is 0 (not 4px) so it matches the preview: the preview's
       separator top margin collapses against the block top, but a flex
       ::before does not collapse \u2014 keeping it 0 aligns both row sets. */
    .tiptap-endnotes-with-separator .ProseMirror::before {
      content: '';
      order: 0;
      width: 33%;
      border-top: 1px solid #444;
      margin: 0 0 8px 0;
    }

    /* Endnote rows inside the overlay: number gutter + content, mirroring the
       preview's number column + gap. */
    .tiptap-endnotes-editor-overlay .tiptap .tiptap-endnote-item {
      position: relative;
      padding-left: 24px;
      margin: 0 0 4px 0;
    }

    .tiptap-endnotes-editor-overlay .tiptap .tiptap-endnote-item::before {
      content: attr(data-endnote-number);
      position: absolute;
      left: 0;
      top: 0;
      width: 18px;
      font-size: 0.8em;
      vertical-align: super;
    }

    /* Toolbar - positioned at TOP edge of overlay, translated UP.
       1px down so its accent border overlays the endnotes separator line. */
    .tiptap-endnotes-edit-toolbar {
      position: absolute;
      top: 1px;
      /* left/right set inline to extend to page borders */
      transform: translateY(-100%);
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 2px solid ${e};
      background: ${D?"linear-gradient(to top, white, transparent)":"transparent"};
      z-index: 1001;
      will-change: transform;
      transition: transform 0.2s ease-in-out;
    }

    .tiptap-endnotes-edit-label {
      position: relative;
      bottom: -2px;
      background: ${e};
      color: white;
      font-size: 11px;
      padding: 3px 10px;
      font-family: system-ui, sans-serif;
      font-weight: 500;
      border-top-right-radius: 4px;
      border-top-left-radius: 4px;
    }

    .tiptap-endnotes-edit-actions {
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 2px 4px;
    }

    .tiptap-endnotes-edit-close {
      background: transparent;
      border: none;
      color: #6b7280;
      cursor: pointer;
      margin: 0;
      padding: 2px;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .tiptap-endnotes-edit-close:hover {
      color: #374151;
    }
  `}var $="footnotes-mask",R=new o.PluginKey("footnotes-page-mask"),B=t.Extension.create({name:"footnotesPageMask",addProseMirrorPlugins:()=>[new o.Plugin({key:R,state:{init:()=>null,apply:(e,t)=>{let o=e.getMeta($);return void 0===o?t:o}},props:{decorations(e){let t=R.getState(e);if(!t)return n.DecorationSet.empty;let o=[];return e.doc.forEach((e,r)=>{if("footnoteItem"!==e.type.name)return;let i=e.attrs.noteId;if("string"!=typeof i)return;if(!t.visibleIds.has(i))return void o.push(n.Decoration.node(r,r+e.nodeSize,{class:"tiptap-footnote-mask-hidden"}));let s=t.numbers[i];void 0!==s&&o.push(n.Decoration.node(r,r+e.nodeSize,{"data-footnote-number":String(s),style:`order: ${s}`}))}),n.DecorationSet.create(e.doc,o)}},appendTransaction:(e,t,n)=>{let r=R.getState(n);if(!r)return null;let i=n.doc.resolve(n.selection.from);if(i.depth>=1){let e=i.node(1),t=e.attrs.noteId;if("footnoteItem"===e.type.name&&"string"==typeof t&&r.visibleIds.has(t))return null}let s=null;return n.doc.forEach((e,t)=>{let o=e.attrs.noteId;null===s&&"footnoteItem"===e.type.name&&"string"==typeof o&&r.visibleIds.has(o)&&(s=t+1)}),null===s?null:n.tr.setSelection(o.TextSelection.near(n.doc.resolve(s)))}})]}),A=`<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M13.2427 4.75736L4.75739 13.2426" stroke="#0F1214" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M13.2427 13.2426L4.7574 4.75736" stroke="#0F1214" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`,J="default",q=class e{constructor(){this.overlay=null,this.editorContainer=null,this.pool=new x,this.measurementEditor=null,this.measurementContainer=null,this.measurementExtensions=[s.ConvertKit],this.storyExtensions=[s.ConvertKit],this.isCollaborative=!1,this.offscreenHost=null,this.currentPageNumber=null,this.currentTarget=null,this.currentOwnerRoot=null,this.onClose=null,this.resizeObserver=null,this.toolbar=null,this.documentDblClickHandler=null,this.onDblClickOutsidePreventClose=null,this.currentZoom=1,this.initialScrollY=0,this.autoUpdateCleanup=null,this.updatePositionFn=null,this.createOverlay()}static getInstance(){return e.instance||(e.instance=new e),e.instance}static destroy(){e.instance&&(e.instance.cleanup(),e.instance=null)}createOverlay(){this.overlay=document.createElement("div"),this.overlay.className="tiptap-footnotes-editor-overlay",this.overlay.style.cssText=`
      position: absolute;
      display: none;
      z-index: 1000;
      background: white;
      box-sizing: border-box;
    `,this.editorContainer=document.createElement("div"),this.editorContainer.className="tiptap-footnotes-editor-container",this.editorContainer.style.cssText=`
      position: absolute;
      bottom: 0;
      left: 0;
      right: 0;
    `,this.overlay.appendChild(this.editorContainer),document.body.appendChild(this.overlay),this.ensureMeasurementEditor(),this.overlay.addEventListener("keydown",e=>{"Escape"===e.key&&(e.preventDefault(),this.hide()),e.stopPropagation()},{capture:!0});let e=e=>e.stopPropagation();this.overlay.addEventListener("keyup",e,{capture:!0}),this.overlay.addEventListener("keypress",e,{capture:!0}),this.overlay.addEventListener("mousedown",e),this.overlay.addEventListener("click",e)}ensureMeasurementEditor(){var e;this.measurementContainer||(this.measurementContainer=document.createElement("div"),this.measurementContainer.className="tiptap-footnotes-editor-measurement",this.measurementContainer.style.cssText=`
        position: absolute;
        left: -10000px;
        top: 0;
        visibility: hidden;
        pointer-events: none;
      `,document.body.appendChild(this.measurementContainer)),null==(e=this.measurementEditor)||e.destroy(),this.measurementEditor=new t.Editor({element:this.measurementContainer,extensions:this.measurementExtensions,content:{type:"doc",content:[{type:"paragraph"}]}})}configure(e){this.pool.destroyAll(),this.storyExtensions=e.storyExtensions.length>0?e.storyExtensions:[s.ConvertKit],this.measurementExtensions=e.measurementExtensions.length>0?e.measurementExtensions:[s.ConvertKit],this.isCollaborative=e.isCollaborative,this.ensureMeasurementEditor(),e.offscreenContentWidth>0&&(this.ensureOffscreenHost(e.offscreenContentWidth),this.pool.setOffscreenHost(this.offscreenHost))}ensureOffscreenHost(e){this.offscreenHost||(this.offscreenHost=document.createElement("div"),this.offscreenHost.className="tiptap-footnotes-editor-offscreen",document.body.appendChild(this.offscreenHost)),this.offscreenHost.style.cssText=`
      position: fixed;
      left: -10000px;
      top: 0;
      visibility: hidden;
      pointer-events: none;
      width: ${e}px;
      box-sizing: border-box;
    `}setOffscreenWidth(e){this.offscreenHost&&e>0&&this.ensureOffscreenHost(e)}eagerlyCreate(){this.ensureStoryEditor()}ensureStoryEditor(){return this.pool.ensure(J,{extensions:this.storyExtensions,isCollaborative:this.isCollaborative,setupContainer:e=>{e.style.cssText=`
          width: 100%;
        `}})}setPersistentUpdateListener(e){this.pool.setPersistentUpdateListener(J,e)}show(e,t,o){var n,i,s;if(!this.overlay||!this.editorContainer)return;this.currentPageNumber=t,this.currentTarget=e,this.currentOwnerRoot=o.ownerRoot||null,this.currentZoom=null!=(n=o.zoom)?n:1,this.onClose=o.onClose||null,this.onDblClickOutsidePreventClose=o.onDblClickOutsidePreventClose||null;let a=this.ensureStoryEditor();this.ensureStoryItems(o.visibleNoteIds,o.numbers),this.applyMask({visibleIds:new Set(o.visibleNoteIds),numbers:o.numbers}),this.pool.mountInto(this.editorContainer,J);let l=window.getComputedStyle(e),d=this.editorContainer.querySelector(".ProseMirror");d instanceof HTMLElement&&(d.style.fontFamily=l.fontFamily,d.style.fontSize=l.fontSize,d.style.lineHeight=l.lineHeight,d.style.color=l.color),this.overlay.classList.toggle("tiptap-footnotes-with-separator",!1!==o.separator),this.initialScrollY=window.scrollY;let h=e.getBoundingClientRect();this.overlay.style.display="block",this.overlay.style.bottom="auto",this.overlay.style.transform="translateY(-100%)",this.overlay.style.height=`${h.height}px`,this.overlay.style.padding="0",this.editorContainer.style.zoom=String(this.currentZoom);let p=()=>{let e=this.getAreaElement(t);if(!this.overlay||!e)return;this.currentTarget=e;let o=e.getBoundingClientRect(),n=window.getComputedStyle(e),r=parseFloat(n.paddingLeft)||0,i=parseFloat(n.paddingRight)||0,s=this.currentZoom,a=o.bottom+window.scrollY;this.overlay.style.left=`${o.left+window.scrollX+r*s}px`,this.overlay.style.top=`${a}px`,this.overlay.style.width=`${o.width-(r+i)*s}px`,this.recomputeOverlayHeight()};this.updatePositionFn=p,p(),this.autoUpdateCleanup=(0,r.autoUpdate)({getBoundingClientRect:()=>{let e=this.getAreaElement(t);return e?e.getBoundingClientRect():{x:0,y:0,top:0,left:0,bottom:0,right:0,width:0,height:0}}},this.overlay,p,{elementResize:!0,layoutShift:!0,ancestorScroll:!0,ancestorResize:!0,animationFrame:!0});let u=null!=(s=null!=(i=o.focusNoteId)?i:o.visibleNoteIds[o.visibleNoteIds.length-1])?s:void 0;setTimeout(()=>{void 0!==u?this.focusFootnote(u):a.commands.focus("end")},0),this.createToolbar(t),this.setupResizeObserver(),this.setupDocumentDblClickHandler()}applyMask(e){let t=this.pool.getEditor(J);t&&t.view.dispatch(t.state.tr.setMeta($,e))}setupDocumentDblClickHandler(){this.removeDocumentDblClickHandler(),this.documentDblClickHandler=e=>{if(!(!this.overlay||"none"===this.overlay.style.display)&&!this.overlay.contains(e.target)){if(this.onDblClickOutsidePreventClose)try{if(this.onDblClickOutsidePreventClose(e))return}catch(e){console.error("[Pages] Error in onDblClickOutsidePreventClose callback:",e)}this.hide()}},document.addEventListener("dblclick",this.documentDblClickHandler)}removeDocumentDblClickHandler(){this.documentDblClickHandler&&(document.removeEventListener("dblclick",this.documentDblClickHandler),this.documentDblClickHandler=null)}createToolbar(e){if(this.removeToolbar(),!this.overlay||!this.currentTarget)return;let t=this.currentZoom,o=window.getComputedStyle(this.currentTarget),n=(parseFloat(o.paddingLeft)||0)*t-1,r=Math.floor((parseFloat(o.paddingRight)||0)*t)-1;this.toolbar=document.createElement("div"),this.toolbar.className="tiptap-footnotes-edit-toolbar",this.toolbar.style.left=`-${n+1}px`,this.toolbar.style.right=`-${r}px`;let i=document.createElement("span");i.className="tiptap-footnotes-edit-label",i.textContent=`Footnotes \u2013 page ${e}`;let s=document.createElement("div");s.className="tiptap-footnotes-edit-actions";let a=document.createElement("button");a.className="tiptap-footnotes-edit-close",a.innerHTML=A,a.type="button",a.onclick=e=>{e.preventDefault(),e.stopPropagation(),this.hide()},s.appendChild(a),this.toolbar.appendChild(i),this.toolbar.appendChild(s),this.overlay.appendChild(this.toolbar)}removeToolbar(){var e;null==(e=this.toolbar)||e.remove(),this.toolbar=null}setupResizeObserver(){var e;if(!this.editorContainer)return;let t=this.editorContainer.querySelector(".ProseMirror");t instanceof HTMLElement&&(null==(e=this.resizeObserver)||e.disconnect(),this.resizeObserver=new ResizeObserver(()=>{this.handleContentResize()}),this.resizeObserver.observe(t))}handleContentResize(){this.recomputeOverlayHeight(),window.scrollTo(0,this.initialScrollY)}recomputeOverlayHeight(){if(!this.overlay||!this.editorContainer)return;let e=this.editorContainer.querySelector(".ProseMirror");if(!(e instanceof HTMLElement)||!e.lastElementChild)return;let t=e.getBoundingClientRect(),o=t.top;for(let t of e.children){let e=t.getBoundingClientRect().bottom;e>o&&(o=e)}let n=o-t.top,r=null!==this.currentPageNumber?this.getAreaElement(this.currentPageNumber):null,i=Math.max(r?r.getBoundingClientRect().height:0,n);Math.abs(i-(Number.parseFloat(this.overlay.style.height)||0))>.5&&(this.overlay.style.height=`${i}px`)}hide(){var e;if(!this.overlay||!this.editorContainer)return;let t=this.currentPageNumber;this.updatePositionFn=null,this.autoUpdateCleanup&&(this.autoUpdateCleanup(),this.autoUpdateCleanup=null),null==(e=this.resizeObserver)||e.disconnect(),this.resizeObserver=null,this.removeToolbar(),this.removeDocumentDblClickHandler(),this.applyMask(null),this.pool.unmount(J),this.overlay.style.display="none",this.editorContainer.style.zoom="",null!==t&&this.onClose&&this.onClose(t),this.currentPageNumber=null,this.currentTarget=null,this.currentOwnerRoot=null,this.onClose=null,this.onDblClickOutsidePreventClose=null}getEditor(){return this.pool.getEditor(J)}getStoryNoteIds(){let e=this.pool.getEditor(J);if(!e)return[];let t=[];return e.state.doc.forEach(e=>{let o=e.attrs.noteId;"footnoteItem"===e.type.name&&"string"==typeof o&&t.push(o)}),t}getFootnoteJSONById(e){let t=this.pool.getEditor(J);if(!t)return null;let o=null;return t.state.doc.forEach(t=>{var n;null===o&&"footnoteItem"===t.type.name&&t.attrs.noteId===e&&(o={type:"doc",content:null!=(n=t.content.toJSON())?n:[]})}),o}getFootnoteHTMLById(e){let t=this.getFootnoteJSONById(e);return t?this.normalizeHTML(t):null}setFootnotesContent(e,t){let o=this.pool.getEditor(J);if(!o)return;let n=e.filter(e=>t[e]).map(e=>{var o;return{type:"footnoteItem",attrs:{noteId:e},content:null!=(o=t[e].content)?o:[{type:"paragraph"}]}});o.commands.setContent({type:"doc",content:n})}ensureStoryItems(e,t){var o;let n=new Set(this.getStoryNoteIds());for(let r of e.filter(e=>!n.has(e)).sort((e,o)=>{var n,r;return(null!=(n=t[e])?n:0)-(null!=(r=t[o])?r:0)})){let e=null!=(o=t[r])?o:Number.MAX_SAFE_INTEGER,n=this.getStoryNoteIds().filter(o=>{var n;return(null!=(n=t[o])?n:0)<e}).length;this.insertFootnoteItem(r,n)}}insertFootnoteItem(e,t){var o;let n=this.pool.getEditor(J);if(!n)return;let r=n.schema.nodes.footnoteItem,i=n.schema.nodes.paragraph;if(!r||!i)return;let s=r.create({noteId:e},i.create()),{doc:a}=n.state;if(1===a.childCount&&(null==(o=a.firstChild)?void 0:o.type.name)==="paragraph"&&0===a.firstChild.content.size)return void n.view.dispatch(n.state.tr.replaceWith(0,a.content.size,s));let l=0,d=0;a.forEach((e,o)=>{d<t&&(l=o+e.nodeSize,d+=1)}),n.view.dispatch(n.state.tr.insert(l,s))}cloneFootnote(e,t){let o=this.pool.getEditor(J);if(!o)return;let n=null,r=null;if(o.state.doc.forEach((t,o)=>{if(null===r&&"footnoteItem"===t.type.name&&t.attrs.noteId===e){n=o+t.nodeSize;let e=t.content.toJSON();r=Array.isArray(e)?e:null}}),null===n)return;let s=o.schema.nodes.footnoteItem,a=o.schema.nodes.paragraph;if(!s||!a)return;let l=r?i.Fragment.fromJSON(o.schema,r):i.Fragment.from(a.create()),d=s.create({noteId:t},l);o.view.dispatch(o.state.tr.insert(n,d))}removeOrphanItems(e){let t=this.pool.getEditor(J);if(!t)return!1;let o=[];if(t.state.doc.forEach((t,n)=>{let r=t.attrs.noteId;"footnoteItem"!==t.type.name||"string"!=typeof r||e.has(r)||o.push({from:n,to:n+t.nodeSize})}),0===o.length)return!1;let n=t.state.tr;for(let e of o.reverse())n=n.delete(e.from,e.to);return t.view.dispatch(n),!0}focusFootnote(e){let t=this.pool.getEditor(J);if(!t)return;let o=null;t.state.doc.forEach((t,n)=>{null===o&&"footnoteItem"===t.type.name&&t.attrs.noteId===e&&(o=n+t.nodeSize-2)}),null!==o&&t.commands.focus(o)}normalizeHTML(e){return this.measurementEditor&&("string"!=typeof e||e.trim())?(this.measurementEditor.commands.setContent(e),this.measurementEditor.getHTML()):"<p></p>"}measureContentHeight(e,t){if(!this.measurementEditor||!this.measurementContainer)return 0;let o=this.measurementContainer.style.cssText;try{this.measurementContainer.style.cssText=`
        position: absolute;
        left: -10000px;
        top: 0;
        visibility: hidden;
        pointer-events: none;
        width: ${t}px;
        height: auto;
        padding: 0;
        box-sizing: border-box;
      `,this.measurementEditor.commands.setContent(e);let o=this.measurementContainer.querySelector(".ProseMirror"),n=0;if(o instanceof HTMLElement&&o.lastElementChild){let e=o.getBoundingClientRect();n=o.lastElementChild.getBoundingClientRect().bottom-e.top}return n}finally{this.measurementContainer.style.cssText=o}}updateZoom(e){var t;this.currentZoom=e,this.editorContainer&&(this.editorContainer.style.zoom=String(e)),null==(t=this.updatePositionFn)||t.call(this),null!==this.currentPageNumber&&this.createToolbar(this.currentPageNumber)}isVisible(){var e;return(null==(e=this.overlay)?void 0:e.style.display)!=="none"}getCurrentPageNumber(){return this.currentPageNumber}getAreaElement(e){let t=`.tiptap-page-footnotes[data-footnotes-page-number="${e}"]`,o=this.currentOwnerRoot?this.currentOwnerRoot.querySelector(t):document.querySelector(t);return o instanceof HTMLElement?o:null}cleanup(){var e,t,o,n;this.autoUpdateCleanup&&(this.autoUpdateCleanup(),this.autoUpdateCleanup=null),this.removeDocumentDblClickHandler(),this.pool.destroyAll(),null==(e=this.offscreenHost)||e.remove(),this.offscreenHost=null,null==(t=this.measurementEditor)||t.destroy(),this.measurementEditor=null,null==(o=this.measurementContainer)||o.remove(),this.measurementContainer=null,null==(n=this.overlay)||n.remove(),this.overlay=null,this.editorContainer=null,this.currentOwnerRoot=null}};q.instance=null;var U="tiptap-footnotes-editor-overlay-styles",j=!0;function G(e){return`
    .tiptap-footnotes-editor-overlay .tiptap {
      outline: none;
      min-height: 1em;
      padding: 0;
      margin: 0;
    }

    .tiptap-footnotes-editor-overlay .tiptap p {
      margin: 0;
      padding: 0;
    }

    .tiptap-footnotes-editor-overlay .tiptap:focus {
      outline: none;
    }

    .tiptap-footnotes-editor-overlay .ProseMirror {
      padding: 0 !important;
      margin: 0 !important;
      caret-color: ${e};
      /* Font metrics are inherited from the page's footnotes area (copied
         onto the container in show()) so preview and editor never drift. */
      /* Flex column so visible items can be sorted by footnote number via
         the mask plugin's order decoration. */
      display: flex;
      flex-direction: column;
    }

    /* Word-style separator rule, matching the rendered preview's geometry. */
    .tiptap-footnotes-with-separator .ProseMirror::before {
      content: '';
      order: 0;
      width: 33%;
      border-top: 1px solid #444;
      margin: 4px 0 8px 0;
    }

    /* Hidden (off-page) footnotes while the overlay is open */
    .tiptap-footnotes-editor-overlay .tiptap .tiptap-footnote-mask-hidden {
      display: none;
    }

    /* Footnote rows inside the overlay: number gutter + content,
       mirroring the preview's 18px number column + 6px gap. */
    .tiptap-footnotes-editor-overlay .tiptap .tiptap-footnote-item {
      position: relative;
      padding-left: 24px;
      margin: 0 0 4px 0;
    }

    .tiptap-footnotes-editor-overlay .tiptap .tiptap-footnote-item::before {
      content: attr(data-footnote-number);
      position: absolute;
      left: 0;
      top: 0;
      width: 18px;
      font-size: 0.8em;
      vertical-align: super;
    }

    /* Toolbar - positioned at TOP edge of overlay, translated UP */
    .tiptap-footnotes-edit-toolbar {
      position: absolute;
      top: 0px;
      /* left/right set inline to extend to page borders */
      transform: translateY(-100%);
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 2px solid ${e};
      background: ${j?"linear-gradient(to top, white, transparent)":"transparent"};
      z-index: 1001;
      will-change: transform;
      transition: transform 0.2s ease-in-out;
    }

    .tiptap-footnotes-edit-label {
      position: relative;
      bottom: -2px;
      background: ${e};
      color: white;
      font-size: 11px;
      padding: 3px 10px;
      font-family: system-ui, sans-serif;
      font-weight: 500;
      border-top-right-radius: 4px;
      border-top-left-radius: 4px;
    }

    .tiptap-footnotes-edit-actions {
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 2px 4px;
    }

    .tiptap-footnotes-edit-close {
      background: transparent;
      border: none;
      color: #6b7280;
      cursor: pointer;
      margin: 0;
      padding: 2px;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .tiptap-footnotes-edit-close:hover {
      color: #374151;
    }
  `}var Z=`<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M13.2427 4.75736L4.75739 13.2426" stroke="#0F1214" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M13.2427 13.2426L4.7574 4.75736" stroke="#0F1214" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`,V=class e{constructor(){this.overlay=null,this.editorContainer=null,this.pool=new x,this.measurementEditor=null,this.measurementContainer=null,this.measurementExtensions=[s.ConvertKit],this.extensionsResolver=()=>this.measurementExtensions,this.isCollaborative=!1,this.offscreenHost=null,this.currentPageNumber=null,this.currentTarget=null,this.currentOwnerRoot=null,this.onContentChange=null,this.onClose=null,this.onHeightChange=null,this.resizeObserver=null,this.resizeDebounceTimer=null,this.toolbar=null,this.documentDblClickHandler=null,this.onDblClickOutsidePreventClose=null,this.currentFooterType="default",this.currentZoom=1,this.minContentHeight=0,this.initialScrollY=0,this.autoUpdateCleanup=null,this.updatePositionFn=null,this.createOverlay()}static getInstance(){return e.instance||(e.instance=new e),e.instance}static destroy(){e.instance&&(e.instance.cleanup(),e.instance=null)}createOverlay(){this.overlay=document.createElement("div"),this.overlay.className="tiptap-footer-editor-overlay",this.overlay.style.cssText=`
      position: absolute;
      display: none;
      z-index: 1000;
      background: white;
      box-sizing: border-box;
    `,this.editorContainer=document.createElement("div"),this.editorContainer.className="tiptap-footer-editor-container",this.editorContainer.style.cssText=`
      position: absolute;
      bottom: 0;
      left: 0;
      right: 0;
    `,this.overlay.appendChild(this.editorContainer),document.body.appendChild(this.overlay),this.ensureMeasurementEditor(),this.overlay.addEventListener("keydown",e=>{"Escape"===e.key&&(e.preventDefault(),this.hide()),e.stopPropagation()},{capture:!0});let e=e=>e.stopPropagation();this.overlay.addEventListener("keyup",e,{capture:!0}),this.overlay.addEventListener("keypress",e,{capture:!0}),this.overlay.addEventListener("mousedown",e),this.overlay.addEventListener("click",e)}ensureMeasurementEditor(){var e;this.measurementContainer||(this.measurementContainer=document.createElement("div"),this.measurementContainer.className="tiptap-footer-editor-measurement",this.measurementContainer.style.cssText=`
        position: absolute;
        left: -10000px;
        top: 0;
        visibility: hidden;
        pointer-events: none;
      `,document.body.appendChild(this.measurementContainer)),null==(e=this.measurementEditor)||e.destroy(),this.measurementEditor=new t.Editor({element:this.measurementContainer,extensions:this.measurementExtensions,content:{type:"doc",content:[{type:"paragraph"}]}})}configure(e){this.pool.destroyAll(),this.measurementExtensions=e.measurementExtensions.length>0?e.measurementExtensions:[s.ConvertKit],this.extensionsResolver=e.extensionsResolver,this.isCollaborative=e.isCollaborative,this.ensureMeasurementEditor(),e.isCollaborative&&"number"==typeof e.offscreenContentWidth&&e.offscreenContentWidth>0?(this.ensureOffscreenHost(e.offscreenContentWidth),this.pool.setOffscreenHost(this.offscreenHost)):(this.pool.setOffscreenHost(null),this.removeOffscreenHost())}ensureOffscreenHost(e){this.offscreenHost||(this.offscreenHost=document.createElement("div"),this.offscreenHost.className="tiptap-footer-editor-offscreen",document.body.appendChild(this.offscreenHost)),this.offscreenHost.style.cssText=`
      position: fixed;
      left: -10000px;
      top: 0;
      visibility: hidden;
      pointer-events: none;
      width: ${e}px;
      box-sizing: border-box;
    `}removeOffscreenHost(){var e;null==(e=this.offscreenHost)||e.remove(),this.offscreenHost=null}setOffscreenWidth(e){this.offscreenHost&&e>0&&this.ensureOffscreenHost(e)}show(e,t,o,n={}){var i,s;if(!this.overlay||!this.editorContainer)return;let a=n.footerType||"default";this.currentPageNumber=t,this.currentTarget=e,this.currentOwnerRoot=n.ownerRoot||null,this.currentFooterType=a,this.currentZoom=null!=(i=n.zoom)?i:1,this.onContentChange=n.onContentChange||null,this.onClose=n.onClose||null,this.onHeightChange=n.onHeightChange||null,this.onDblClickOutsidePreventClose=n.onDblClickOutsidePreventClose||null;let l=this.ensureAndMountSubType(a,o);if(!l)return;this.initialScrollY=window.scrollY;let d=e.getBoundingClientRect(),h=parseFloat(window.getComputedStyle(e).paddingBottom)||0,p=d.height-h*this.currentZoom;this.minContentHeight=null!=(s=n.baseMinHeight)?s:p/this.currentZoom,this.overlay.style.display="block",this.overlay.style.bottom="auto",this.overlay.style.transform="translateY(-100%)",this.overlay.style.height=`${p}px`,this.overlay.style.padding="0",this.editorContainer.style.zoom=String(this.currentZoom);let u=()=>{let e=this.getFooterElement(t);if(!this.overlay||!e)return;this.currentTarget=e;let o=e.getBoundingClientRect(),n=window.getComputedStyle(e),r=parseFloat(n.paddingLeft)||0,i=parseFloat(n.paddingRight)||0,s=parseFloat(n.paddingBottom)||0,a=this.currentZoom,l=o.bottom-s*a+window.scrollY;this.overlay.style.left=`${o.left+window.scrollX+r*a}px`,this.overlay.style.top=`${l}px`,this.overlay.style.width=`${o.width-(r+i)*a}px`};this.updatePositionFn=u,u(),this.autoUpdateCleanup=(0,r.autoUpdate)({getBoundingClientRect:()=>{let e=this.getFooterElement(t);return e?e.getBoundingClientRect():{x:0,y:0,top:0,left:0,bottom:0,right:0,width:0,height:0}}},this.overlay,u,{elementResize:!0,layoutShift:!0,ancestorScroll:!0,ancestorResize:!0,animationFrame:!0}),this.isCollaborative||l.commands.setContent(o),setTimeout(()=>{var e;null==(e=this.pool.getEditor(this.currentFooterType))||e.commands.focus("end")},0),this.createToolbar(t),this.setupResizeObserver(),this.setupDocumentDblClickHandler()}ensureAndMountSubType(e,t){if(!this.editorContainer)return null;let o=this.ensureSubType(e,t);return this.pool.mountInto(this.editorContainer,e),this.pool.setUpdateListener(e,()=>{var e;null==(e=this.onContentChange)||e.call(this)}),o}ensureSubType(e,t){return this.pool.ensure(e,{extensions:this.extensionsResolver(e),isCollaborative:this.isCollaborative,initialContent:t,setupContainer:e=>{e.style.cssText=`
          width: 100%;
        `}})}eagerlyCreateAllSubTypes(){for(let e of["default","first","odd","even"])this.ensureSubType(e)}setPersistentUpdateListener(e,t){this.pool.setPersistentUpdateListener(e,t)}setPersistentHeightListener(e,t){this.pool.setPersistentHeightListener(e,t)}getLastContentHeight(e){return this.pool.getLastContentHeight(e)}setupDocumentDblClickHandler(){this.removeDocumentDblClickHandler(),this.documentDblClickHandler=e=>{if(!(!this.overlay||"none"===this.overlay.style.display)&&!this.overlay.contains(e.target)){if(this.onDblClickOutsidePreventClose)try{if(this.onDblClickOutsidePreventClose(e))return}catch(e){console.error("[Pages] Error in onDblClickOutsidePreventClose callback:",e)}this.hide()}},document.addEventListener("dblclick",this.documentDblClickHandler)}removeDocumentDblClickHandler(){this.documentDblClickHandler&&(document.removeEventListener("dblclick",this.documentDblClickHandler),this.documentDblClickHandler=null)}createToolbar(e){if(this.removeToolbar(),!this.overlay||!this.currentTarget)return;let t=this.currentZoom,o=window.getComputedStyle(this.currentTarget),n=(parseFloat(o.paddingLeft)||0)*t-1,r=Math.floor((parseFloat(o.paddingRight)||0)*t)-1;this.toolbar=document.createElement("div"),this.toolbar.className="tiptap-footer-edit-toolbar",this.toolbar.style.left=`-${n+1}px`,this.toolbar.style.right=`-${r}px`;let i=document.createElement("span");i.className="tiptap-footer-edit-label",i.textContent=this.getFooterLabel(e,this.currentFooterType);let s=document.createElement("div");s.className="tiptap-footer-edit-actions";let a=document.createElement("button");a.className="tiptap-footer-edit-close",a.innerHTML=Z,a.type="button",a.onclick=e=>{e.preventDefault(),e.stopPropagation(),this.hide()},s.appendChild(a),this.toolbar.appendChild(i),this.toolbar.appendChild(s),this.overlay.appendChild(this.toolbar)}removeToolbar(){var e;null==(e=this.toolbar)||e.remove(),this.toolbar=null}getFooterLabel(e,t){switch(t){case"first":return"First page footer";case"odd":return"Odd pages footer";case"even":return"Even pages footer";default:{let t=["th","st","nd","rd"],o=e%100;return`${e}${t[(o-20)%10]||t[o]||t[0]} page footer`}}}setupResizeObserver(){var e;if(!this.editorContainer)return;let t=this.editorContainer.querySelector(".ProseMirror");t&&(null==(e=this.resizeObserver)||e.disconnect(),this.resizeObserver=new ResizeObserver(()=>{this.debouncedHeightChange()}),this.resizeObserver.observe(t))}debouncedHeightChange(){var e,t;if(!this.overlay||!this.editorContainer)return;let o=this.editorContainer.querySelector(".ProseMirror");if(!o||!o.lastElementChild)return;let n=o.getBoundingClientRect(),r=(o.lastElementChild.getBoundingClientRect().bottom-n.top)/this.currentZoom,i=null==(e=this.currentTarget)?void 0:e.getBoundingClientRect(),s=(null!=(t=null==i?void 0:i.height)?t:0)/this.currentZoom,a=this.currentTarget?window.getComputedStyle(this.currentTarget):null,l=Math.max(0,s-((a&&parseFloat(a.paddingTop)||0)+(a&&parseFloat(a.paddingBottom)||0))),d=Math.max(this.minContentHeight,l,r)*this.currentZoom;this.overlay.style.height=`${d}px`,window.scrollTo(0,this.initialScrollY),this.onHeightChange&&this.onHeightChange(r)}hide(){var e;if(!this.overlay||!this.editorContainer)return;let t=this.currentPageNumber,o=this.editorContainer.querySelector(".ProseMirror"),n=0;if(null!=o&&o.lastElementChild){let e=o.getBoundingClientRect();n=(o.lastElementChild.getBoundingClientRect().bottom-e.top)/this.currentZoom}this.updatePositionFn=null,this.autoUpdateCleanup&&(this.autoUpdateCleanup(),this.autoUpdateCleanup=null),null==(e=this.resizeObserver)||e.disconnect(),this.resizeObserver=null,this.resizeDebounceTimer&&(window.clearTimeout(this.resizeDebounceTimer),this.resizeDebounceTimer=null),this.removeToolbar(),this.removeDocumentDblClickHandler(),this.pool.setUpdateListener(this.currentFooterType,null),this.pool.unmount(this.currentFooterType),this.overlay.style.display="none",this.editorContainer.style.zoom="",null!==t&&this.onClose&&this.onClose(t,n),this.currentPageNumber=null,this.currentTarget=null,this.currentOwnerRoot=null,this.onContentChange=null,this.onClose=null,this.onHeightChange=null,this.onDblClickOutsidePreventClose=null}getHTML(){var e;return(null==(e=this.pool.getEditor(this.currentFooterType))?void 0:e.getHTML())||""}getJSON(){var e;return(null==(e=this.pool.getEditor(this.currentFooterType))?void 0:e.getJSON())||{type:"doc",content:[]}}normalizeHTML(e){return this.measurementEditor&&("string"!=typeof e||e.trim())?(this.measurementEditor.commands.setContent(e),this.measurementEditor.getHTML()):"<p></p>"}normalize(e){return this.measurementEditor&&("string"!=typeof e||e.trim())?(this.measurementEditor.commands.setContent(e),{html:this.measurementEditor.getHTML(),json:this.measurementEditor.getJSON()}):{html:"<p></p>",json:{type:"doc",content:[{type:"paragraph"}]}}}updateZoom(e){var t;this.currentZoom=e,this.editorContainer&&(this.editorContainer.style.zoom=String(e)),null==(t=this.updatePositionFn)||t.call(this),null!==this.currentPageNumber&&this.createToolbar(this.currentPageNumber)}isVisible(){var e;return(null==(e=this.overlay)?void 0:e.style.display)!=="none"}getCurrentPageNumber(){return this.currentPageNumber}getCurrentTarget(){return this.currentTarget}getEditor(){return this.pool.getEditor(this.currentFooterType)}getEditorForSubType(e){return this.pool.getEditor(e)}measureContentHeight(e,t){if(!this.measurementEditor||!this.measurementContainer)return 0;let o=this.measurementContainer.style.cssText;try{this.measurementContainer.style.cssText=`
        position: absolute;
        left: -10000px;
        top: 0;
        visibility: hidden;
        pointer-events: none;
        width: ${t}px;
        height: auto;
        padding: 0;
        box-sizing: border-box;
      `,this.measurementEditor.commands.setContent(e);let o=this.measurementContainer.querySelector(".ProseMirror"),n=0;if(null!=o&&o.lastElementChild){let e=o.getBoundingClientRect();n=o.lastElementChild.getBoundingClientRect().bottom-e.top}return n}finally{this.measurementContainer.style.cssText=o}}getFooterElement(e){let t=`.tiptap-page-footer[data-footer-page-number="${e}"]`,o=this.currentOwnerRoot?this.currentOwnerRoot.querySelector(t):document.querySelector(t);return o instanceof HTMLElement?o:null}cleanup(){var e,t,o;this.autoUpdateCleanup&&(this.autoUpdateCleanup(),this.autoUpdateCleanup=null),this.removeDocumentDblClickHandler(),this.pool.destroyAll(),this.removeOffscreenHost(),null==(e=this.measurementEditor)||e.destroy(),this.measurementEditor=null,null==(t=this.measurementContainer)||t.remove(),this.measurementContainer=null,null==(o=this.overlay)||o.remove(),this.overlay=null,this.editorContainer=null,this.currentOwnerRoot=null}};V.instance=null;var W="tiptap-footer-editor-overlay-styles",K=!0;function _(e){return`
    .tiptap-footer-editor-overlay {
      /* position: absolute is set inline */
    }

    .tiptap-footer-editor-overlay .tiptap-footer-editor-container {
      /* Absolute positioning at bottom - content grows upward naturally */
    }

    .tiptap-footer-editor-overlay .tiptap {
      outline: none;
      min-height: 1em;
      padding: 0;
      margin: 0;
    }

    .tiptap-footer-editor-overlay .tiptap p {
      margin: 0;
      padding: 0;
    }

    .tiptap-footer-editor-overlay .tiptap:focus {
      outline: none;
    }

    .tiptap-footer-editor-overlay .ProseMirror {
      padding: 0 !important;
      margin: 0 !important;
      caret-color: ${e};
    }

    /* Toolbar - positioned at TOP edge of overlay, translated UP */
    .tiptap-footer-edit-toolbar {
      position: absolute;
      top: 0px;
      /* left/right set inline to extend to page borders */
      transform: translateY(-100%);
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 2px solid ${e};
      background: ${K?"linear-gradient(to top, white, transparent)":"transparent"};
      z-index: 1001;
      will-change: transform;
      transition: transform 0.2s ease-in-out;
    }

    /* Label on the left - border radius at top for footer */
    .tiptap-footer-edit-label {
      position: relative;
      bottom: -2px;
      background: ${e};
      color: white;
      font-size: 11px;
      padding: 3px 10px;
      font-family: system-ui, sans-serif;
      font-weight: 500;
      border-top-right-radius: 4px;
      border-top-left-radius: 4px;
    }

    /* Actions container on the right */
    .tiptap-footer-edit-actions {
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 2px 4px;
    }

    /* Close button */
    .tiptap-footer-edit-close {
      background: transparent;
      border: none;
      color: #6b7280;
      cursor: pointer;
      margin: 0;
      padding: 2px;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .tiptap-footer-edit-close:hover {
      color: #374151;
    }
  `}function Y(e){let t=document.getElementById(W);t&&(t.textContent=_(e))}var X=`<svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M13.2427 4.75736L4.75739 13.2426" stroke="#0F1214" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M13.2427 13.2426L4.7574 4.75736" stroke="#0F1214" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`,Q=class e{constructor(){this.overlay=null,this.editorContainer=null,this.pool=new x,this.measurementEditor=null,this.measurementContainer=null,this.measurementExtensions=[s.ConvertKit],this.extensionsResolver=()=>this.measurementExtensions,this.isCollaborative=!1,this.offscreenHost=null,this.currentPageNumber=null,this.currentTarget=null,this.currentOwnerRoot=null,this.onContentChange=null,this.onClose=null,this.onHeightChange=null,this.resizeObserver=null,this.resizeDebounceTimer=null,this.toolbar=null,this.documentDblClickHandler=null,this.onDblClickOutsidePreventClose=null,this.currentHeaderType="default",this.currentZoom=1,this.minContentHeight=0,this.initialScrollY=0,this.autoUpdateCleanup=null,this.updatePositionFn=null,this.createOverlay()}static getInstance(){return e.instance||(e.instance=new e),e.instance}static destroy(){e.instance&&(e.instance.cleanup(),e.instance=null)}createOverlay(){this.overlay=document.createElement("div"),this.overlay.className="tiptap-header-editor-overlay",this.overlay.style.cssText=`
      position: absolute;
      display: none;
      z-index: 1000;
      background: white;
      box-sizing: border-box;
    `,this.editorContainer=document.createElement("div"),this.editorContainer.className="tiptap-header-editor-container",this.overlay.appendChild(this.editorContainer),document.body.appendChild(this.overlay),this.ensureMeasurementEditor(),this.overlay.addEventListener("keydown",e=>{"Escape"===e.key&&(e.preventDefault(),this.hide()),e.stopPropagation()},{capture:!0});let e=e=>e.stopPropagation();this.overlay.addEventListener("keyup",e,{capture:!0}),this.overlay.addEventListener("keypress",e,{capture:!0}),this.overlay.addEventListener("mousedown",e),this.overlay.addEventListener("click",e)}ensureMeasurementEditor(){var e;this.measurementContainer||(this.measurementContainer=document.createElement("div"),this.measurementContainer.className="tiptap-header-editor-measurement",this.measurementContainer.style.cssText=`
        position: absolute;
        left: -10000px;
        top: 0;
        visibility: hidden;
        pointer-events: none;
      `,document.body.appendChild(this.measurementContainer)),null==(e=this.measurementEditor)||e.destroy(),this.measurementEditor=new t.Editor({element:this.measurementContainer,extensions:this.measurementExtensions,content:{type:"doc",content:[{type:"paragraph"}]}})}configure(e){this.pool.destroyAll(),this.measurementExtensions=e.measurementExtensions.length>0?e.measurementExtensions:[s.ConvertKit],this.extensionsResolver=e.extensionsResolver,this.isCollaborative=e.isCollaborative,this.ensureMeasurementEditor(),e.isCollaborative&&"number"==typeof e.offscreenContentWidth&&e.offscreenContentWidth>0?(this.ensureOffscreenHost(e.offscreenContentWidth),this.pool.setOffscreenHost(this.offscreenHost)):(this.pool.setOffscreenHost(null),this.removeOffscreenHost())}ensureOffscreenHost(e){this.offscreenHost||(this.offscreenHost=document.createElement("div"),this.offscreenHost.className="tiptap-header-editor-offscreen",document.body.appendChild(this.offscreenHost)),this.offscreenHost.style.cssText=`
      position: fixed;
      left: -10000px;
      top: 0;
      visibility: hidden;
      pointer-events: none;
      width: ${e}px;
      box-sizing: border-box;
    `}removeOffscreenHost(){var e;null==(e=this.offscreenHost)||e.remove(),this.offscreenHost=null}setOffscreenWidth(e){this.offscreenHost&&e>0&&this.ensureOffscreenHost(e)}show(e,t,o,n={}){var i,s;if(!this.overlay||!this.editorContainer)return;let a=n.headerType||"default";this.currentPageNumber=t,this.currentTarget=e,this.currentOwnerRoot=n.ownerRoot||null,this.currentHeaderType=a,this.currentZoom=null!=(i=n.zoom)?i:1,this.onContentChange=n.onContentChange||null,this.onClose=n.onClose||null,this.onHeightChange=n.onHeightChange||null,this.onDblClickOutsidePreventClose=n.onDblClickOutsidePreventClose||null;let l=this.ensureAndMountSubType(a,o);if(!l)return;this.initialScrollY=window.scrollY;let d=e.getBoundingClientRect(),h=parseFloat(window.getComputedStyle(e).paddingTop)||0,p=d.height-h*this.currentZoom;this.minContentHeight=null!=(s=n.baseMinHeight)?s:p/this.currentZoom,this.overlay.style.display="block",this.overlay.style.height=`${p}px`,this.overlay.style.padding="0",this.editorContainer.style.zoom=String(this.currentZoom);let u=()=>{let e=this.getHeaderElement(t);if(!this.overlay||!e)return;this.currentTarget=e;let o=e.getBoundingClientRect(),n=window.getComputedStyle(e),r=parseFloat(n.paddingLeft)||0,i=parseFloat(n.paddingRight)||0,s=parseFloat(n.paddingTop)||0,a=this.currentZoom;this.overlay.style.left=`${o.left+window.scrollX+r*a}px`,this.overlay.style.top=`${o.top+window.scrollY+s*a}px`,this.overlay.style.width=`${o.width-(r+i)*a}px`};this.updatePositionFn=u,u(),this.autoUpdateCleanup=(0,r.autoUpdate)({getBoundingClientRect:()=>{let e=this.getHeaderElement(t);return e?e.getBoundingClientRect():{x:0,y:0,top:0,left:0,bottom:0,right:0,width:0,height:0}}},this.overlay,u,{elementResize:!0,layoutShift:!0,ancestorScroll:!0,ancestorResize:!0,animationFrame:!0}),this.isCollaborative||l.commands.setContent(o),setTimeout(()=>{var e;null==(e=this.pool.getEditor(this.currentHeaderType))||e.commands.focus("end")},0),this.createToolbar(t),this.setupResizeObserver(),this.setupDocumentDblClickHandler()}ensureAndMountSubType(e,t){if(!this.editorContainer)return null;let o=this.ensureSubType(e,t);return this.pool.mountInto(this.editorContainer,e),this.pool.setUpdateListener(e,()=>{var e;null==(e=this.onContentChange)||e.call(this)}),o}ensureSubType(e,t){return this.pool.ensure(e,{extensions:this.extensionsResolver(e),isCollaborative:this.isCollaborative,initialContent:t,setupContainer:e=>{e.style.cssText=`
          width: 100%;
          min-height: 100%;
        `}})}eagerlyCreateAllSubTypes(){for(let e of["default","first","odd","even"])this.ensureSubType(e)}setPersistentUpdateListener(e,t){this.pool.setPersistentUpdateListener(e,t)}setPersistentHeightListener(e,t){this.pool.setPersistentHeightListener(e,t)}getLastContentHeight(e){return this.pool.getLastContentHeight(e)}setupDocumentDblClickHandler(){this.removeDocumentDblClickHandler(),this.documentDblClickHandler=e=>{if(!(!this.overlay||"none"===this.overlay.style.display)&&!this.overlay.contains(e.target)){if(this.onDblClickOutsidePreventClose)try{if(this.onDblClickOutsidePreventClose(e))return}catch(e){console.error("[Pages] Error in onDblClickOutsidePreventClose callback:",e)}this.hide()}},document.addEventListener("dblclick",this.documentDblClickHandler)}removeDocumentDblClickHandler(){this.documentDblClickHandler&&(document.removeEventListener("dblclick",this.documentDblClickHandler),this.documentDblClickHandler=null)}createToolbar(e){if(this.removeToolbar(),!this.overlay||!this.currentTarget)return;let t=this.currentZoom,o=window.getComputedStyle(this.currentTarget),n=(parseFloat(o.paddingLeft)||0)*t-1,r=Math.floor((parseFloat(o.paddingRight)||0)*t)-1;this.toolbar=document.createElement("div"),this.toolbar.className="tiptap-header-edit-toolbar",this.toolbar.style.left=`-${n+1}px`,this.toolbar.style.right=`-${r}px`;let i=document.createElement("span");i.className="tiptap-header-edit-label",i.textContent=this.getHeaderLabel(e,this.currentHeaderType);let s=document.createElement("div");s.className="tiptap-header-edit-actions";let a=document.createElement("button");a.className="tiptap-header-edit-close",a.innerHTML=X,a.type="button",a.onclick=e=>{e.preventDefault(),e.stopPropagation(),this.hide()},s.appendChild(a),this.toolbar.appendChild(i),this.toolbar.appendChild(s),this.overlay.appendChild(this.toolbar)}removeToolbar(){var e;null==(e=this.toolbar)||e.remove(),this.toolbar=null}getHeaderLabel(e,t){switch(t){case"first":return"First page header";case"odd":return"Odd pages header";case"even":return"Even pages header";default:{let t=["th","st","nd","rd"],o=e%100;return`${e}${t[(o-20)%10]||t[o]||t[0]} page header`}}}setupResizeObserver(){var e;if(!this.editorContainer)return;let t=this.editorContainer.querySelector(".ProseMirror");t&&(null==(e=this.resizeObserver)||e.disconnect(),this.resizeObserver=new ResizeObserver(()=>{this.debouncedHeightChange()}),this.resizeObserver.observe(t))}debouncedHeightChange(){var e,t;if(!this.overlay||!this.editorContainer)return;let o=this.editorContainer.querySelector(".ProseMirror");if(!o||!o.lastElementChild)return;let n=o.getBoundingClientRect(),r=(o.lastElementChild.getBoundingClientRect().bottom-n.top)/this.currentZoom,i=null==(e=this.currentTarget)?void 0:e.getBoundingClientRect(),s=(null!=(t=null==i?void 0:i.height)?t:0)/this.currentZoom,a=this.currentTarget?window.getComputedStyle(this.currentTarget):null,l=Math.max(0,s-((a&&parseFloat(a.paddingTop)||0)+(a&&parseFloat(a.paddingBottom)||0))),d=Math.max(this.minContentHeight,l,r)*this.currentZoom;this.overlay.style.height=`${d}px`,window.scrollTo(0,this.initialScrollY),this.onHeightChange&&this.onHeightChange(r)}hide(){var e;if(!this.overlay||!this.editorContainer)return;let t=this.currentPageNumber,o=this.editorContainer.querySelector(".ProseMirror"),n=0;if(null!=o&&o.lastElementChild){let e=o.getBoundingClientRect();n=(o.lastElementChild.getBoundingClientRect().bottom-e.top)/this.currentZoom}this.updatePositionFn=null,this.autoUpdateCleanup&&(this.autoUpdateCleanup(),this.autoUpdateCleanup=null),null==(e=this.resizeObserver)||e.disconnect(),this.resizeObserver=null,this.resizeDebounceTimer&&(window.clearTimeout(this.resizeDebounceTimer),this.resizeDebounceTimer=null),this.removeToolbar(),this.removeDocumentDblClickHandler(),this.pool.setUpdateListener(this.currentHeaderType,null),this.pool.unmount(this.currentHeaderType),this.overlay.style.display="none",this.editorContainer.style.zoom="",null!==t&&this.onClose&&this.onClose(t,n),this.currentPageNumber=null,this.currentTarget=null,this.currentOwnerRoot=null,this.onContentChange=null,this.onClose=null,this.onHeightChange=null,this.onDblClickOutsidePreventClose=null}getHTML(){var e;return(null==(e=this.pool.getEditor(this.currentHeaderType))?void 0:e.getHTML())||""}getJSON(){var e;return(null==(e=this.pool.getEditor(this.currentHeaderType))?void 0:e.getJSON())||{type:"doc",content:[]}}normalizeHTML(e){return this.measurementEditor&&("string"!=typeof e||e.trim())?(this.measurementEditor.commands.setContent(e),this.measurementEditor.getHTML()):"<p></p>"}normalize(e){return this.measurementEditor&&("string"!=typeof e||e.trim())?(this.measurementEditor.commands.setContent(e),{html:this.measurementEditor.getHTML(),json:this.measurementEditor.getJSON()}):{html:"<p></p>",json:{type:"doc",content:[{type:"paragraph"}]}}}updateZoom(e){var t;this.currentZoom=e,this.editorContainer&&(this.editorContainer.style.zoom=String(e)),null==(t=this.updatePositionFn)||t.call(this),null!==this.currentPageNumber&&this.createToolbar(this.currentPageNumber)}isVisible(){var e;return(null==(e=this.overlay)?void 0:e.style.display)!=="none"}getCurrentPageNumber(){return this.currentPageNumber}getCurrentTarget(){return this.currentTarget}getEditor(){return this.pool.getEditor(this.currentHeaderType)}getEditorForSubType(e){return this.pool.getEditor(e)}measureContentHeight(e,t){if(!this.measurementEditor||!this.measurementContainer)return 0;let o=this.measurementContainer.style.cssText;try{this.measurementContainer.style.cssText=`
        position: absolute;
        left: -10000px;
        top: 0;
        visibility: hidden;
        pointer-events: none;
        width: ${t}px;
        height: auto;
        padding: 0;
        box-sizing: border-box;
      `,this.measurementEditor.commands.setContent(e);let o=this.measurementContainer.querySelector(".ProseMirror"),n=0;if(null!=o&&o.lastElementChild){let e=o.getBoundingClientRect();n=o.lastElementChild.getBoundingClientRect().bottom-e.top}return n}finally{this.measurementContainer.style.cssText=o}}getHeaderElement(e){let t=`.tiptap-page-header[data-header-page-number="${e}"]`,o=this.currentOwnerRoot?this.currentOwnerRoot.querySelector(t):document.querySelector(t);return o instanceof HTMLElement?o:null}cleanup(){var e,t,o;this.autoUpdateCleanup&&(this.autoUpdateCleanup(),this.autoUpdateCleanup=null),this.removeDocumentDblClickHandler(),this.pool.destroyAll(),this.removeOffscreenHost(),null==(e=this.measurementEditor)||e.destroy(),this.measurementEditor=null,null==(t=this.measurementContainer)||t.remove(),this.measurementContainer=null,null==(o=this.overlay)||o.remove(),this.overlay=null,this.editorContainer=null,this.currentOwnerRoot=null}};Q.instance=null;var ee="tiptap-header-editor-overlay-styles",et=!0;function eo(e){return`
    .tiptap-header-editor-overlay {
      /* position: absolute is set inline */
    }

    .tiptap-header-editor-overlay .tiptap-header-editor-container {
      width: 100%;
      min-height: 100%;
    }

    .tiptap-header-editor-overlay .tiptap {
      outline: none;
      min-height: 1em;
      padding: 0;
      margin: 0;
    }

    .tiptap-header-editor-overlay .tiptap p {
      margin: 0;
      padding: 0;
    }

    .tiptap-header-editor-overlay .tiptap:focus {
      outline: none;
    }

    .tiptap-header-editor-overlay .ProseMirror {
      padding: 0 !important;
      margin: 0 !important;
      caret-color: ${e};
    }

    /* Toolbar - positioned at bottom edge of overlay, translated down */
    .tiptap-header-edit-toolbar {
      position: absolute;
      bottom: 0px;
      /* left/right set inline to extend to page borders */
      transform: translateY(100%);
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-top: 2px solid ${e};
      background: ${et?"linear-gradient(to bottom, white, transparent)":"transparent"};
      z-index: 1001;
    }

    /* Label on the left */
    .tiptap-header-edit-label {
      position: relative;
      top: -2px;
      background: ${e};
      color: white;
      font-size: 11px;
      padding: 3px 10px;
      font-family: system-ui, sans-serif;
      font-weight: 500;
      border-bottom-right-radius: 4px;
      border-bottom-left-radius: 4px;
    }

    /* Actions container on the right */
    .tiptap-header-edit-actions {
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 2px 4px;
    }

    /* Close button */
    .tiptap-header-edit-close {
      background: transparent;
      border: none;
      color: #6b7280;
      cursor: pointer;
      margin: 0;
      padding: 2px;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .tiptap-header-edit-close:hover {
      color: #374151;
    }
  `}function en(e){let t=document.getElementById(ee);t&&(t.textContent=eo(e))}function er(e,t){return 1===e&&t.differentFirstPage?"first":t.differentOddEven?e%2==1?"odd":"even":"default"}function ei(e,t){return 1===e&&t.differentFirstPageFooter?"first":t.differentOddEvenFooter?e%2==1?"odd":"even":"default"}var es=[],ea=0,el=null;function ed(e){let t=e.getBoundingClientRect(),o=e.offsetWidth>0?t.width/e.offsetWidth:0,n=e.offsetHeight>0?t.height/e.offsetHeight:0,r=Number.parseFloat(e.style.zoom||"1")||1,i=o||n||r;return Number.isFinite(i)&&i>0?i:1}var eh=null,ep=null;function eu(){eh=null,ep=null}function eg(e){let t=e.dom;return ep!==t&&(ep=t,eh=t.querySelector("[data-tiptap-pagination]")),eh?eh.children.length:0}function ec(e,t="u">typeof window&&window.devicePixelRatio?Math.round(96*window.devicePixelRatio):96){return e*t/2.54}var ef={A4:{id:"A4",width:ec(21,96),height:ec(29.7,96),margins:{top:ec(2.5,96),right:ec(2,96),bottom:ec(2.5,96),left:ec(2,96)}},A3:{id:"A3",width:ec(29.7,96),height:ec(42,96),margins:{top:ec(2.5,96),right:ec(2,96),bottom:ec(2.5,96),left:ec(2,96)}},A5:{id:"A5",width:ec(14.8,96),height:ec(21,96),margins:{top:ec(2,96),right:ec(1.5,96),bottom:ec(2,96),left:ec(1.5,96)}},Letter:{id:"Letter",width:ec(21.59,96),height:ec(27.94,96),margins:{top:ec(2.54,96),right:ec(2.54,96),bottom:ec(2.54,96),left:ec(2.54,96)}},Legal:{id:"Legal",width:ec(21.59,96),height:ec(35.56,96),margins:{top:ec(2.54,96),right:ec(2.54,96),bottom:ec(2.54,96),left:ec(2.54,96)}},Tabloid:{id:"Tabloid",width:ec(27.94,96),height:ec(43.18,96),margins:{top:ec(2.54,96),right:ec(2.54,96),bottom:ec(2.54,96),left:ec(2.54,96)}}},em=null,ev=null;function eb(){em=null,ev=null}function ey(e){var t,o,n,r;let i=["string"==typeof e.pageFormat?e.pageFormat:JSON.stringify(e.pageFormat),e.headerTopMargin,e.footerBottomMargin,e.pageGap,e.pageGapBackground].join("|");if(i===em&&ev)return ev;let s="string"==typeof e.pageFormat?ef[e.pageFormat]:e.pageFormat,a=.5*s.margins.top,l=.5*s.margins.bottom,d={width:s.width,height:s.height,margins:s.margins,headerTopMargin:null!=(t=e.headerTopMargin)?t:a,footerBottomMargin:null!=(o=e.footerBottomMargin)?o:l,pageGap:null!=(n=e.pageGap)?n:50,footer:e.footer,header:e.header,pageGapBackground:null!=(r=e.pageGapBackground)?r:"#fff"};return em=i,ev=d,d}function eC(e,t,o){var n,r,i,s,a,l,d,h;let p=er(e,o),u=ei(e,o),g=0;switch(p){case"first":g=null!=(n=o.headerFirstPageContentHeight)?n:0;break;case"odd":g=null!=(r=o.headerOddContentHeight)?r:0;break;case"even":g=null!=(i=o.headerEvenContentHeight)?i:0;break;default:g=null!=(s=o.headerContentHeight)?s:0}let c=0;switch(u){case"first":c=null!=(a=o.footerFirstPageContentHeight)?a:0;break;case"odd":c=null!=(l=o.footerOddContentHeight)?l:0;break;case"even":c=null!=(d=o.footerEvenContentHeight)?d:0;break;default:c=null!=(h=o.footerContentHeight)?h:0}return t.height-t.margins.top-t.margins.bottom-g-c}function ew({view:e,options:t,storage:o}){var n,r;let i=ey({...t,pageFormat:o.pageFormat,pageGap:o.pageGap,headerTopMargin:o.headerTopMargin,footerBottomMargin:o.footerBottomMargin,footer:o.footer,header:o.header,pageGapBackground:o.pageGapBackground}),s=e.dom,a=s.querySelector("[data-tiptap-pagination]"),l=eg(e);if(a){let e=s.lastElementChild,t=null==(n=a.lastElementChild)?void 0:n.querySelector(".breaker");if(e&&t){let n=ed(s),a=e.getBoundingClientRect(),d=t.getBoundingClientRect(),h=(a.bottom-d.bottom)/n,p=function(e,t){let o=Date.now();if(o<ea&&null!=el)return{stop:!0,stablePageCount:el,shouldWarn:!1};es.length>0&&o-es[es.length-1].timestamp>2e3&&(es.length=0);let n=es[es.length-1];if(n&&n.pageCount===e?(n.gap=t,n.timestamp=o):(es.push({pageCount:e,gap:t,timestamp:o}),es.length>6&&es.shift()),es.length>=4){let[e,t,n,r]=es.slice(-4),i=e.pageCount===n.pageCount&&t.pageCount===r.pageCount&&e.pageCount!==t.pageCount,s=r.timestamp-e.timestamp<1e3;if(i&&s){let n=Math.min(e.pageCount,t.pageCount);return es.length=0,ea=o+2e3,el=n,{stop:!0,stablePageCount:n,shouldWarn:!0}}}if(6===es.length){let e=es[0],t=es[5],n=t.pageCount>e.pageCount,r=50>Math.abs(t.gap-e.gap);if(n&&r){let t=Math.max(1,e.pageCount);return es.length=0,ea=o+2e3,el=t,{stop:!0,stablePageCount:t,shouldWarn:!0}}}return{stop:!1}}(l,h);if(p.stop)return p.shouldWarn&&console.warn(`[Pages] A non-floatable element exceeds page height limits, this can cause pagination break.

Find out how to fix this: https://tiptap.dev/docs/pages/core-concepts/limitations

Read more about non-floating elements here: https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Block_formatting_context`),Math.max(2,null!=(r=p.stablePageCount)?r:l);if(h>0){let e=h,t=0,n=l+1;for(;e>0;)e-=eC(n,i,o),t+=1,n+=1;return Math.max(2,l+t)}let u=-(i.height-10);return h>u&&h<-10?Math.max(2,l):h<u?Math.max(2,l+Math.floor(h/(i.height+50))):Math.max(2,l)}return 2}let d=s.scrollHeight,h=0,p=0;for(;h<d;)p+=1,h+=eC(p,i,o);return Math.max(2,p+1)}var eE=(e,t)=>{let o=e.querySelector("[data-tiptap-pagination]");if(o){let t=o.querySelectorAll(".tiptap-page-footer"),n=t[t.length-1];if(n){let t=ed(e),r=o.getBoundingClientRect(),i=n.getBoundingClientRect(),s=`${Math.round((i.bottom-r.top)/t)}px`;e.style.minHeight!==s&&(e.style.minHeight=s)}}if(t&&t.size>0)for(let o=0;o<5;o++){let o=e.querySelectorAll(".tiptap-page-break-node--pages-mode"),n=!1;for(let e of o)if(e instanceof HTMLElement){let o=t.get(e);if(o){let t=e.style.height;o(),t!==e.style.height&&(n=!0)}}if(!n)break}},eH="PAGE_COUNT_META_KEY";function eT({view:e,options:t,storage:o}){var n;let r,i=(n=()=>{let n=e.dom;if(eg(e)!==ew({view:e,options:t,storage:o})){let t=e.state.tr.setMeta(eH,Date.now());e.dispatch(t),requestAnimationFrame(()=>{eE(n,o.onAfterPageLayoutCallbacks)})}else eE(n,o.onAfterPageLayoutCallbacks)},r=null,(...e)=>{r&&clearTimeout(r),r=setTimeout(()=>{r=null,n(...e)},0)});o.mutationObserver||(o.mutationObserver=new MutationObserver(e=>{0!==e.length&&i()}),o.mutationObserver.observe(e.dom,{attributes:!0}))}function eM({view:e,options:t,storage:o}){var n,r,i,s,a,l,d,h,p,u,g,c,f,m,v,b,y;let C,w,E=e.dom;E.classList.contains(o.uniqueId)||E.classList.add(o.uniqueId);let H=ey({...t,pageFormat:o.pageFormat,pageGap:o.pageGap,headerTopMargin:o.headerTopMargin,footerBottomMargin:o.footerBottomMargin,footer:o.footer,header:o.header,pageGapBackground:o.pageGapBackground}),T=(w=(C=Object.values(o.footnoteAreaHeights)).length>0?Math.max(...C):0,[H.width,H.height,H.margins.top,H.margins.bottom,H.margins.left,H.margins.right,H.pageGap,H.headerTopMargin,H.footerBottomMargin,o.headerContentHeight,o.headerFirstPageContentHeight,o.headerOddContentHeight,o.headerEvenContentHeight,o.footerContentHeight,o.footerFirstPageContentHeight,o.footerOddContentHeight,o.footerEvenContentHeight,o.differentFirstPage,o.differentOddEven,o.differentFirstPageFooter,o.differentOddEvenFooter,o.footnotesAccentColor,Math.round(w)].join("|"));if(o.styleHash===T&&o.styleElement)return void eT({view:e,options:t,storage:o});o.styleHash=T,null!=(n=o.styleElement)&&n.parentNode&&o.styleElement.parentNode.removeChild(o.styleElement);let M=document.createElement("style");M.dataset.tiptapPaginationStyle=o.uniqueId;let O=`.${o.uniqueId}`,x=0;x=o.differentOddEven?o.differentFirstPage?Math.max(null!=(r=o.headerFirstPageContentHeight)?r:0,null!=(i=o.headerOddContentHeight)?i:0,null!=(s=o.headerEvenContentHeight)?s:0):Math.max(null!=(a=o.headerOddContentHeight)?a:0,null!=(l=o.headerEvenContentHeight)?l:0):o.differentFirstPage?Math.max(null!=(d=o.headerFirstPageContentHeight)?d:0,null!=(h=o.headerContentHeight)?h:0):null!=(p=o.headerContentHeight)?p:0;let P=0;P=o.differentOddEvenFooter?o.differentFirstPageFooter?Math.max(null!=(u=o.footerFirstPageContentHeight)?u:0,null!=(g=o.footerOddContentHeight)?g:0,null!=(c=o.footerEvenContentHeight)?c:0):Math.max(null!=(f=o.footerOddContentHeight)?f:0,null!=(m=o.footerEvenContentHeight)?m:0):o.differentFirstPageFooter?Math.max(null!=(v=o.footerFirstPageContentHeight)?v:0,null!=(b=o.footerContentHeight)?b:0):null!=(y=o.footerContentHeight)?y:0;let F=Object.values(o.footnoteAreaHeights),k=F.length>0?Math.max(...F):0,S=H.height-H.margins.top-H.margins.bottom-x-P-k-20;E.style.setProperty("--page-max-height",`${S}px`),M.textContent=`
        ${O} {
          width: ${H.width}px;
          margin: 50px auto;
          background-color: #fff;
          border: 1px solid #e5e5e5;
          padding: 0px ${H.margins.right}px 0px ${H.margins.left}px;
          box-sizing: border-box;
        }

        /* Apply disabled styles to all descendants except pagination elements */
        ${O}[contenteditable=false] * {
          user-select: none;
          cursor: default;
          opacity: 0.5;
        }

        /* Reset styles for pagination elements (headers/footers) */
        ${O}[contenteditable=false] [data-tiptap-pagination="true"],
        ${O}[contenteditable=false] [data-tiptap-pagination="true"] * {
          user-select: auto;
          cursor: auto;
          opacity: 1;
        }

        /* Reset styles for header/footer editor overlays */
        ${O}[contenteditable=false] .tiptap-header-editor-overlay,
        ${O}[contenteditable=false] .tiptap-header-editor-overlay *,
        ${O}[contenteditable=false] .tiptap-footer-editor-overlay,
        ${O}[contenteditable=false] .tiptap-footer-editor-overlay *,
        ${O}[contenteditable=false] .tiptap-footnotes-editor-overlay,
        ${O}[contenteditable=false] .tiptap-footnotes-editor-overlay * {
          user-select: auto;
          cursor: auto;
          opacity: 1;
        }

        /* Give everything that falls within the pagination container a border-box box-sizing */
        /* This helps with consistent sizing and layout calculations */
        ${O} * {
          box-sizing: border-box;
        }

        /* Give a remote user a caret */
        ${O} .collaboration-carets__caret {
          border-left: 1px solid #0d0d0d;
          border-right: 1px solid #0d0d0d;
          margin-left: -1px;
          margin-right: -1px;
          pointer-events: none;
          position: relative;
          word-break: normal;
        }

        /* Render the username above the caret */
        ${O} .collaboration-carets__label {
          border-radius: 3px 3px 3px 0;
          color: #0d0d0d;
          font-size: 12px;
          font-style: normal;
          font-weight: 600;
          left: -1px;
          line-height: normal;
          padding: 0.1rem 0.3rem;
          position: absolute;
          top: -1.4em;
          user-select: none;
          white-space: nowrap;
        }

        ${O} .tiptap-pagination-gap {
          border-top: 1px solid #e5e5e5;
          border-bottom: 1px solid #e5e5e5;
        }

        ${O} .tiptap-page-footer::after {
          color: #6b7280; /* Tailwind text-gray-500 */
        }

        /* Footnote reference markers in the body */
        ${O} .tiptap-footnote-ref::after {
          content: attr(data-footnote-number);
        }

        ${O} .tiptap-footnote-ref {
          color: ${o.footnotesAccentColor};
          cursor: pointer;
          user-select: none;
        }

        /* Per-page footnotes area (above the footer) */
        ${O} .tiptap-page-footnotes {
          box-sizing: border-box;
          font-size: 0.85em;
          line-height: 1.35;
        }

        ${O} .tiptap-footnotes-separator {
          width: 33%;
          border-top: 1px solid #444;
          margin: 4px 0 8px 0;
        }

        ${O} .tiptap-page-footnote {
          display: flex;
          gap: 6px;
          margin-bottom: 4px;
        }

        ${O} .tiptap-footnote-number {
          flex: 0 0 18px;
          font-size: 0.8em;
          vertical-align: super;
        }

        ${O} .tiptap-footnote-content p {
          margin: 0;
          padding: 0;
        }

        /* Keep empty paragraphs visible \u2014 users add vertical spacing with
           Enter, and a bare <p></p> would collapse to zero height. */
        ${O} .tiptap-footnote-content p:empty::before {
          content: '\\00a0';
          display: inline;
        }

        /* Endnote reference markers in the body (lowercase Roman numerals). */
        ${O} .tiptap-endnote-ref::after {
          content: attr(data-endnote-number);
        }

        ${O} .tiptap-endnote-ref {
          color: ${o.endnotesAccentColor};
          cursor: pointer;
          user-select: none;
        }

        /* Document-end endnotes block \u2014 flows after the last body block. */
        ${O} .tiptap-endnotes {
          box-sizing: border-box;
          font-size: 0.85em;
          line-height: 1.35;
          margin-top: 16px;
        }

        ${O} .tiptap-endnotes-separator {
          width: 33%;
          border-top: 1px solid #444;
          margin: 0 0 8px 0;
        }

        /* Block layout with an absolutely-positioned marker (NOT flex): the
           endnotes block flows in paginated content, so a single endnote may
           span a page break. A flex row cannot split across the Pages
           margin-spacer pagination \u2014 it collapses to ~one word per line and
           explodes vertically \u2014 so the row must be normal block flow. */
        ${O} .tiptap-endnote {
          position: relative;
          padding-left: 24px;
          margin-bottom: 4px;
        }

        ${O} .tiptap-endnote-number {
          position: absolute;
          left: 0;
          top: 0;
          width: 18px;
          font-size: 0.8em;
          vertical-align: super;
        }

        ${O} .tiptap-endnote-content p {
          margin: 0;
          padding: 0;
        }

        ${O} .tiptap-endnote-content p:empty::before {
          content: '\\00a0';
          display: inline;
        }

        ${O} .tiptap-page-footer {
          background-color: hsl(var(--background));
          display: block;
          width: 100%;
          box-sizing: border-box;
          color: #6b7280;
        }

        ${O} .tiptap-page-header {
          background-color: hsl(var(--background));
          display: flex;
          flex-direction: column;
          width: 100%;
          box-sizing: border-box;
          color: #6b7280;
        }

        ${O} .tiptap-page-footer {
          background-color: hsl(var(--background));
          display: flex;
          flex-direction: column;
          width: 100%;
          box-sizing: border-box;
          color: #6b7280;
        }

        ${O} .tiptap-page-header p,
        ${O} .tiptap-page-footer p {
          margin: 0;
        }

        /* Maintain height for empty paragraphs (match editor's <br> behavior) */
        ${O} .tiptap-page-header p:empty::before,
        ${O} .tiptap-page-footer p:empty::before {
          content: '\\00a0';
          display: inline;
        }

        ${O} .tiptap-page-header-center,
        ${O} .tiptap-page-footer-center {
          flex: 1;
          text-align: center;
        }

        ${O} {
          counter-reset: page-number;
        }

        ${O} .tiptap-page-footer {
          counter-increment: page-number;
        }

        ${O} .tiptap-page-break:last-child .tiptap-pagination-gap {
          display: none;
        }

        ${O} .tiptap-page-break:last-child .tiptap-page-header {
          display: none;
        }

        ${O} p:has(br.ProseMirror-trailingBreak:only-child) {
          display: table; /* Fallback for older browsers */
          display: flow-root;
          width: 100%;
        }

        ${O} .tiptap-page-header-center {
          flex: 1;
          text-align: center;
        }

        ${O} table {
          border-collapse: collapse;
          width: 100%;
          display: contents;
        }

        ${O} table tbody {
          width: 100%;
          display: contents;
        }

        ${O} table tbody tr, ${O} table tr {
          width: 100%;
          max-width: 100%;
          min-width: 0;
          /* Fallback for browsers that don't support overflow-x: clip; supporting browsers will use clip below. */
          overflow-x: hidden;
          overflow-x: clip;
          position: relative;
          box-sizing: border-box;
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(0, 1fr));
        }

        ${O} table tbody tr td,
        ${O} table tbody tr th,
        ${O} table tr td,
        ${O} table tr th {
          box-sizing: border-box;
          position: relative;
          min-width: 0;
        }
      `,document.head.appendChild(M),o.styleElement=M,eT({view:e,options:t,storage:o}),requestAnimationFrame(()=>eE(e.dom,o.onAfterPageLayoutCallbacks))}function eO(e){return e.replace(/[.*+?^${}()|[\]\\]/g,"\\$&")}function ex(e,t,o,n){let r=Object.keys(n);if(0===r.length||!e.includes("{"))return e;let i=RegExp(`\\{(${r.map(eO).join("|")})\\}`,"g");return e.replace(i,(e,r)=>"page"===n[r]?String(t):String(o))}var eP=new Map;function eF(e){return Object.keys(e).sort().join(",")}function ek(){eP.clear()}function eS(e,t,o){if(!o[t]){let n=Q.getInstance();o[t]=n.normalizeHTML(e)}return o[t]}function eN(e,t,o){if(!o[t]){let n=V.getInstance();o[t]=n.normalizeHTML(e)}return o[t]}function eL(e,t){var o,n,r,i;switch(e){case"first":return null!=(o=t.headerFirstPageContentHeight)?o:0;case"odd":return null!=(n=t.headerOddContentHeight)?n:0;case"even":return null!=(r=t.headerEvenContentHeight)?r:0;default:return null!=(i=t.headerContentHeight)?i:0}}function eI(e,t){var o,n,r,i;switch(e){case"first":return null!=(o=t.footerFirstPageContentHeight)?o:0;case"odd":return null!=(n=t.footerOddContentHeight)?n:0;case"even":return null!=(r=t.footerEvenContentHeight)?r:0;default:return null!=(i=t.footerContentHeight)?i:0}}function eD({state:e,options:t,storage:o,pageCount:r}){var i;let s=ey({...t,pageFormat:o.pageFormat,pageGap:o.pageGap,headerTopMargin:o.headerTopMargin,footerBottomMargin:o.footerBottomMargin,footer:o.footer,header:o.header,pageGapBackground:o.pageGapBackground}),a=!1===(i=t.placeholders)?{}:i?{["string"==typeof i.page&&""!==i.page.trim()?i.page:"page"]:"page",["string"==typeof i.total&&""!==i.total.trim()?i.total:"total"]:"total"}:{page:"page",total:"total"},l=n.Decoration.widget(0,e=>{var n;let i=s.pageGap,l=null!=(n=s.pageGapBackground)?n:"#ffffff",d=s.width,h=document.createElement("div");h.dataset.tiptapPagination="true";let p=({firstPage:e=!1,pageNumber:t=0,totalPages:n=0,headerTypes:r,footerTypes:h})=>{var p,u,g;let c=eL(r.get(t)||"default",o),f=eI(h.get(t)||"default",o),m=o.footnotesEnabled&&null!=(p=o.footnoteAreaHeights[t])?p:0,v=s.height-s.margins.top-s.margins.bottom-c-f-m,b=t+1,y=r.get(b)||"default",C=eL(y,o),w=h.get(t)||"default",E=eI(w,o),H=document.createElement("div");H.classList.add("tiptap-page-break");let T,M,O,x,P=document.createElement("div");P.classList.add("page"),P.style.position="relative",P.style.float="left",P.style.clear="both",P.style.marginTop=e?"0px":`${v}px`,P.dataset.pageNumber=t.toString();let F=document.createElement("div");if(F.classList.add("breaker"),F.style.width=`calc(${d}px)`,F.style.marginLeft=`-${s.margins.left}px`,F.style.position="relative",F.style.float="left",F.style.clear="both",F.style.left="0px",F.style.right="0px",F.style.zIndex="2",F.dataset.pageNumber=t.toString(),!e){let e,r=o.footnotesEnabled&&null!=(u=o.footnotePageAssignments[t])?u:[];r.length>0&&((T=document.createElement("div")).classList.add("tiptap-page-footnotes"),T.style.height=`${m}px`,T.style.overflow="hidden",T.style.padding=`0 ${s.margins.right}px 0 ${s.margins.left}px`,T.dataset.editable=o.editableFootnotes?"true":"false",T.dataset.footnotesPageNumber=t.toString(),T.style.cursor=o.editableFootnotes?"pointer":"default",T.innerHTML=0===(e=[...(g={idsOnPage:r,htmlById:o.footnotesHTML,numbers:o.footnoteNumbers,separator:o.footnotesSeparator}).idsOnPage].sort((e,t)=>{var o,n;return(null!=(o=g.numbers[e])?o:0)-(null!=(n=g.numbers[t])?n:0)})).length?"":(g.separator?'<div class="tiptap-footnotes-separator"></div>':"")+e.map(e=>{var t;let o=null!=(t=g.numbers[e])?t:0,n="string"==typeof g.htmlById[e]?g.htmlById[e]:"<p></p>";return`<div class="tiptap-page-footnote" data-note-id="${e}"><span class="tiptap-footnote-number">${o}</span><div class="tiptap-footnote-content">${n}</div></div>`}).join("")),(M=document.createElement("div")).classList.add("tiptap-page-footer");let d=s.margins.bottom+E;M.style.minHeight=`${d}px`,M.style.height=`${d}px`,M.style.padding=`0 ${s.margins.right}px ${s.footerBottomMargin}px ${s.margins.left}px`,M.style.display="flex",M.style.flexDirection="column",M.style.justifyContent="flex-end",M.dataset.editable=o.editableFooter?"true":"false",M.dataset.footerPageNumber=t.toString(),M.dataset.footerType=w,M.style.cursor=o.editableFooter?"pointer":"default";let h=V.getInstance();h.isVisible()&&h.getCurrentPageNumber()===t&&(M.dataset.editing="true"),x=function(e,t,o,n,r,i={page:"page",total:"total"}){let s,a=`footer-${e}-${t}-${o}-${n.uniqueId}-${eF(i)}`,l=eP.get(a);if(l)return l;switch(e){case"first":s=n.footerFirstPageHTML?n.footerFirstPageHTML:n.footerFirstPage?eN(n.footerFirstPage,"normalizedFirstPageFooterTemplate",n):"";break;case"odd":s=n.footerOddHTML?n.footerOddHTML:n.footerOdd?eN(n.footerOdd,"normalizedOddFooterTemplate",n):"";break;case"even":s=n.footerEvenHTML?n.footerEvenHTML:n.footerEven?eN(n.footerEven,"normalizedEvenFooterTemplate",n):"";break;default:s=n.footerHTML?n.footerHTML:eN(r.footer,"normalizedFooterTemplate",n)}let d=ex(s,t,o,i);return eP.set(a,d),d}(w,t,n,o,s,a),M.innerHTML=x,(O=document.createElement("div")).classList.add("tiptap-pagination-gap"),O.style.height=`${i}px`,O.style.borderLeft="1px solid",O.style.borderRight="1px solid",O.style.position="relative",O.style.setProperty("width","calc(100% + 2px)","important"),O.style.left="-1px",O.style.backgroundColor=l,O.style.borderLeftColor=l,O.style.borderRightColor=l}let k=document.createElement("div");k.classList.add("tiptap-page-header");let S=s.margins.top+C;k.style.minHeight=`${S}px`,k.style.height=`${S}px`,k.style.padding=`${s.headerTopMargin}px ${s.margins.right}px 0 ${s.margins.left}px`,k.dataset.editable=o.editableHeader?"true":"false",k.dataset.headerPageNumber=b.toString(),k.dataset.headerType=y,k.style.cursor=o.editableHeader?"pointer":"default";let N=Q.getInstance();for(let t of(N.isVisible()&&N.getCurrentPageNumber()===b&&(k.dataset.editing="true"),k.innerHTML=function(e,t,o,n,r,i={page:"page",total:"total"}){let s,a=`header-${e}-${t}-${o}-${n.uniqueId}-${eF(i)}`,l=eP.get(a);if(l)return l;switch(e){case"first":s=n.headerFirstPageHTML?n.headerFirstPageHTML:n.headerFirstPage?eS(n.headerFirstPage,"normalizedFirstPageTemplate",n):"";break;case"odd":s=n.headerOddHTML?n.headerOddHTML:n.headerOdd?eS(n.headerOdd,"normalizedOddTemplate",n):"";break;case"even":s=n.headerEvenHTML?n.headerEvenHTML:n.headerEven?eS(n.headerEven,"normalizedEvenTemplate",n):"";break;default:s=n.headerHTML?n.headerHTML:eS(r.header,"normalizedHeaderTemplate",n)}let d=ex(s,t,o,i);return eP.set(a,d),d}(y,b,n,o,s,a),e?[k]:[T,M,O,k]))t&&F.append(t);return H.append(P,F),H},u=document.createDocumentFragment(),g=null!=r?r:ew({view:e,options:t,storage:o}),{headerTypes:c,footerTypes:f}=function(e,t){let o=new Map,n=new Map;for(let r=0;r<e;r++){let e=r+1;o.set(e,er(e,t)),n.set(r,ei(r,t))}return{headerTypes:o,footerTypes:n}}(g,o),m=0;for(;m<g;){let e=p({firstPage:0===m,lastPage:!1,pageNumber:m,totalPages:g-1,headerTypes:c,footerTypes:f});e.dataset.pageNumber=m.toString(),u.appendChild(e.cloneNode(!0)),m+=1}return h.append(u),h.id="pages",h},{side:-1}),d=o.endnotesEnabled?Object.keys(o.endnoteNumbers):[],h=d.length>0?n.Decoration.widget(e.doc.content.size,()=>{var e;let t,n=document.createElement("div");return n.classList.add("tiptap-endnotes"),n.contentEditable="false",n.dataset.editable=o.editableEndnotes?"true":"false",n.style.cursor=o.editableEndnotes?"pointer":"default",n.innerHTML=0===(t=[...(e={orderedIds:d,htmlById:o.endnotesHTML,numbers:o.endnoteNumbers,separator:o.endnotesSeparator}).orderedIds].sort((t,o)=>{var n,r;return(null!=(n=e.numbers[t])?n:0)-(null!=(r=e.numbers[o])?r:0)})).length?"":(e.separator?'<div class="tiptap-endnotes-separator"></div>':"")+t.map(t=>{var o;let n=f(null!=(o=e.numbers[t])?o:0),r="string"==typeof e.htmlById[t]?e.htmlById[t]:"<p></p>";return`<div class="tiptap-endnote" data-note-id="${t}"><span class="tiptap-endnote-number">${n}</span><div class="tiptap-endnote-content">${r}</div></div>`}).join(""),n},{side:1}):null;return h?[l,h]:[l]}function ez(e){switch(e){case"first":return{getHTML:e=>e.headerFirstPageHTML,setHTML:(e,t)=>{e.headerFirstPageHTML=t},getJSON:e=>e.headerFirstPageJSON,setJSON:(e,t)=>{e.headerFirstPageJSON=t},getHeight:e=>e.headerFirstPageContentHeight,setHeight:(e,t)=>{e.headerFirstPageContentHeight=t}};case"odd":return{getHTML:e=>e.headerOddHTML,setHTML:(e,t)=>{e.headerOddHTML=t},getJSON:e=>e.headerOddJSON,setJSON:(e,t)=>{e.headerOddJSON=t},getHeight:e=>e.headerOddContentHeight,setHeight:(e,t)=>{e.headerOddContentHeight=t}};case"even":return{getHTML:e=>e.headerEvenHTML,setHTML:(e,t)=>{e.headerEvenHTML=t},getJSON:e=>e.headerEvenJSON,setJSON:(e,t)=>{e.headerEvenJSON=t},getHeight:e=>e.headerEvenContentHeight,setHeight:(e,t)=>{e.headerEvenContentHeight=t}};default:return{getHTML:e=>e.headerHTML,setHTML:(e,t)=>{e.headerHTML=t},getJSON:e=>e.headerJSON,setJSON:(e,t)=>{e.headerJSON=t},getHeight:e=>e.headerContentHeight,setHeight:(e,t)=>{e.headerContentHeight=t}}}}function e$(e){switch(e){case"first":return{getHTML:e=>e.footerFirstPageHTML,setHTML:(e,t)=>{e.footerFirstPageHTML=t},getJSON:e=>e.footerFirstPageJSON,setJSON:(e,t)=>{e.footerFirstPageJSON=t},getHeight:e=>e.footerFirstPageContentHeight,setHeight:(e,t)=>{e.footerFirstPageContentHeight=t}};case"odd":return{getHTML:e=>e.footerOddHTML,setHTML:(e,t)=>{e.footerOddHTML=t},getJSON:e=>e.footerOddJSON,setJSON:(e,t)=>{e.footerOddJSON=t},getHeight:e=>e.footerOddContentHeight,setHeight:(e,t)=>{e.footerOddContentHeight=t}};case"even":return{getHTML:e=>e.footerEvenHTML,setHTML:(e,t)=>{e.footerEvenHTML=t},getJSON:e=>e.footerEvenJSON,setJSON:(e,t)=>{e.footerEvenJSON=t},getHeight:e=>e.footerEvenContentHeight,setHeight:(e,t)=>{e.footerEvenContentHeight=t}};default:return{getHTML:e=>e.footerHTML,setHTML:(e,t)=>{e.footerHTML=t},getJSON:e=>e.footerJSON,setJSON:(e,t)=>{e.footerJSON=t},getHeight:e=>e.footerContentHeight,setHeight:(e,t)=>{e.footerContentHeight=t}}}}function eR(e,t){var o;let n=ey({...e,pageFormat:t.pageFormat,headerTopMargin:t.headerTopMargin,footerBottomMargin:t.footerBottomMargin}),r=null!=(o=t.headerTopMargin)?o:n.headerTopMargin,i=n.margins.top-r;return{availableSpace:i,baseMinHeight:i}}function eB(e,t){var o;let n=ey({...e,pageFormat:t.pageFormat,headerTopMargin:t.headerTopMargin,footerBottomMargin:t.footerBottomMargin}),r=null!=(o=t.footerBottomMargin)?o:n.footerBottomMargin,i=n.margins.bottom-r;return{availableSpace:i,baseMinHeight:i}}function eA(e,t){return Math.max(0,e-t)}var eJ=["default","first","odd","even"];function eq(e){return void 0!==e&&eJ.some(t=>t===e)}function eU({candidate:e,measureContentHeight:t}){let o;if(!t)return e.fallbackContentHeight;try{o=t(e.content,e.contentWidth)}catch{return e.fallbackContentHeight}return!Number.isFinite(o)||o<0?e.fallbackContentHeight:o}function ej(e,t,o){let n=e.get(t);return!n||o>n.fallbackContentHeight}function eG(e){let t={element:e,height:e.style.height,minHeight:e.style.minHeight};return e.style.height="auto",e.style.minHeight="0",t}function eZ(e){e.element.style.height=e.height,e.element.style.minHeight=e.minHeight}function eV({view:e,options:t,storage:o,measureHeaderContentHeight:n,measureFooterContentHeight:r}){var i,s;let a=ey({...t,pageFormat:o.pageFormat,pageGap:o.pageGap,headerTopMargin:o.headerTopMargin,footerBottomMargin:o.footerBottomMargin,footer:o.footer,header:o.header,pageGapBackground:o.pageGapBackground}),l=null!=(i=o.headerTopMargin)?i:a.headerTopMargin,d=null!=(s=o.footerBottomMargin)?s:a.footerBottomMargin,h=a.margins.top-l,p=a.margins.bottom-d,u=!1,g=!1,c=ed(e.dom),f=new Map,m=e.dom.querySelectorAll(".tiptap-page-header[data-header-type]"),v=[];for(let e of m){let t=e.dataset.headerType;eq(t)&&"none"!==window.getComputedStyle(e).display&&v.push({element:e,headerType:t})}let b=v.map(e=>eG(e.element));for(let e=0;e<v.length;e+=1){let t=v[e];if(!t)continue;let o=t.element.getBoundingClientRect(),n=o.height/c-l;if(!ej(f,t.headerType,n))continue;let r=window.getComputedStyle(t.element),i=parseFloat(r.paddingLeft)||0,s=parseFloat(r.paddingRight)||0,a=Math.max(0,o.width/c-i-s);f.set(t.headerType,{content:t.element.innerHTML,contentWidth:a,fallbackContentHeight:n})}for(let e of b)eZ(e);for(let[e,t]of f){let r=eA(eU({candidate:t,measureContentHeight:n}),h),i=ez(e);r!==i.getHeight(o)&&(i.setHeight(o,r),u=!0)}let y=new Map,C=e.dom.querySelectorAll(".tiptap-page-footer[data-footer-type]"),w=[];for(let e of C){let t=e.dataset.footerType;eq(t)&&"none"!==window.getComputedStyle(e).display&&w.push({element:e,footerType:t})}let E=w.map(e=>eG(e.element));for(let e=0;e<w.length;e+=1){let t=w[e];if(!t)continue;let o=t.element.getBoundingClientRect(),n=o.height/c-d;if(!ej(y,t.footerType,n))continue;let r=window.getComputedStyle(t.element),i=parseFloat(r.paddingLeft)||0,s=parseFloat(r.paddingRight)||0,a=Math.max(0,o.width/c-i-s);y.set(t.footerType,{content:t.element.innerHTML,contentWidth:a,fallbackContentHeight:n})}for(let e of E)eZ(e);for(let[e,t]of y){let n=eA(eU({candidate:t,measureContentHeight:r}),p),i=e$(e);n!==i.getHeight(o)&&(i.setHeight(o,n),g=!0)}return{headerChanged:u,footerChanged:g}}function eW(e,t){var o;let{focusNoteId:n}=e,{editor:r,options:i,storage:s}=t;if(!s.endnotesEnabled||!s.editableEndnotes)return!1;let a=r.view.dom.querySelector(".tiptap-endnotes");if(!(a instanceof HTMLElement))return!1;let l=L.getInstance();l.isVisible()&&l.hide();let d=Object.keys(s.endnoteNumbers).sort((e,t)=>s.endnoteNumbers[e]-s.endnoteNumbers[t]);return l.show(a,{noteIds:d,numbers:s.endnoteNumbers,separator:s.endnotesSeparator,focusNoteId:n,zoom:null!=(o=s.zoom)?o:1,ownerRoot:r.view.dom,onDblClickOutsidePreventClose:i.onDblClickEndnotesPreventClose||i.onDblClickHeaderFooterPreventClose,onClose:()=>{var e;"endnotes"===s.activeEditorType&&(r.setEditable(null==(e=s.wasEditable)||e),s.activeEditor=null,s.activeEditorType=null,s.activePageNumber=null),r.emit("update",{editor:r,transaction:r.state.tr,appendedTransactions:[]})}}),s.wasEditable=r.isEditable,r.setEditable(!1),s.activeEditor=l.getEditor(),s.activeEditorType="endnotes",s.activePageNumber=null,r.emit("update",{editor:r,transaction:r.state.tr,appendedTransactions:[]}),!0}function eK(e,t){var o,n;let{pageNumber:r,focusNoteId:i}=e,{editor:s,options:a,storage:l}=t;if(!l.footnotesEnabled||!l.editableFootnotes)return!1;let d=s.view.dom.querySelector(`.tiptap-page-footnotes[data-footnotes-page-number="${r}"]`);if(!(d instanceof HTMLElement))return!1;let h=q.getInstance();h.isVisible()&&h.hide();let p=null!=(o=l.footnotePageAssignments[r])?o:[];return h.show(d,r,{visibleNoteIds:p,numbers:l.footnoteNumbers,separator:l.footnotesSeparator,focusNoteId:i,zoom:null!=(n=l.zoom)?n:1,ownerRoot:s.view.dom,onDblClickOutsidePreventClose:a.onDblClickFootnotesPreventClose||a.onDblClickHeaderFooterPreventClose,onClose:()=>{var e;"footnotes"===l.activeEditorType&&(s.setEditable(null==(e=l.wasEditable)||e),l.activeEditor=null,l.activeEditorType=null,l.activePageNumber=null),s.emit("update",{editor:s,transaction:s.state.tr,appendedTransactions:[]})}}),l.wasEditable=s.isEditable,s.setEditable(!1),l.activeEditor=h.getEditor(),l.activeEditorType="footnotes",l.activePageNumber=r,s.emit("update",{editor:s,transaction:s.state.tr,appendedTransactions:[]}),!0}function e_(e){let{editor:t,view:o,options:n,storage:r,accessors:i,metaKey:s,getOverlayHTML:a,getOverlayJSON:l,isOtherOverlayVisible:d,heightContext:h}=e;return{onContentChange:()=>{i.setHTML(r,a()),i.setJSON(r,l())},onHeightChange:e=>{let t=eA(e,h.availableSpace);if(t!==i.getHeight(r)){i.setHeight(r,t);let e=o.state.tr.setMeta(s,Date.now());o.dispatch(e),eM({view:o,options:n,storage:r})}},onClose:(e,p)=>{var u;i.setHTML(r,a()),i.setJSON(r,l()),ek(),d()||t.setEditable(null==(u=r.wasEditable)||u),r.activeEditor=null,r.activeEditorType=null,r.activePageNumber=null;let g=eA(p,h.availableSpace);i.setHeight(r,g);let c=o.state.tr.setMeta(s,Date.now());o.dispatch(c),eM({view:o,options:n,storage:r}),t.emit("update",{editor:t,transaction:t.state.tr,appendedTransactions:[]})}}}function eY(e,t){var o;let{pageNumber:n}=e,{editor:r,options:i,storage:s,headerOverlay:a,footerOverlay:l}=t;if(!s.editableHeader)return!1;let d=r.view.dom.querySelector(`.tiptap-page-header[data-header-page-number="${n}"]`);if(!d)return!1;a.isVisible()&&a.hide();let h=d.dataset.headerType||er(n,s),p=ez(h),u=p.getHTML(s)||d.innerHTML,g=eR(i,s),c=e_({editor:r,view:r.view,options:i,storage:s,accessors:p,metaKey:"header-change",editorType:"header",getOverlayHTML:()=>a.getHTML(),getOverlayJSON:()=>a.getJSON(),isOtherOverlayVisible:()=>l.isVisible(),heightContext:g});a.show(d,n,u,{headerType:h,baseMinHeight:g.baseMinHeight,zoom:null!=(o=s.zoom)?o:1,onContentChange:c.onContentChange,onHeightChange:c.onHeightChange,onClose:c.onClose,ownerRoot:r.view.dom,onDblClickOutsidePreventClose:i.onDblClickHeaderPreventClose||i.onDblClickHeaderFooterPreventClose});let f=r.view.dom.querySelector(`.tiptap-page-header[data-header-page-number="${n}"]`);return f&&(f.dataset.editing="true"),l.isVisible()||(s.wasEditable=r.isEditable),r.setEditable(!1),s.activeEditor=a.getEditor(),s.activeEditorType="header",s.activePageNumber=n,r.emit("update",{editor:r,transaction:r.state.tr,appendedTransactions:[]}),!0}function eX(e,t){var o;let{pageNumber:n}=e,{editor:r,options:i,storage:s,headerOverlay:a,footerOverlay:l}=t;if(!s.editableFooter)return!1;let d=r.view.dom.querySelector(`.tiptap-page-footer[data-footer-page-number="${n}"]`);if(!d)return!1;l.isVisible()&&l.hide();let h=d.dataset.footerType||ei(n,s),p=e$(h),u=p.getHTML(s)||d.innerHTML,g=eB(i,s),c=e_({editor:r,view:r.view,options:i,storage:s,accessors:p,metaKey:"footer-change",editorType:"footer",getOverlayHTML:()=>l.getHTML(),getOverlayJSON:()=>l.getJSON(),isOtherOverlayVisible:()=>a.isVisible(),heightContext:g});l.show(d,n,u,{footerType:h,baseMinHeight:g.baseMinHeight,zoom:null!=(o=s.zoom)?o:1,onContentChange:c.onContentChange,onHeightChange:c.onHeightChange,onClose:c.onClose,ownerRoot:r.view.dom,onDblClickOutsidePreventClose:i.onDblClickFooterPreventClose||i.onDblClickHeaderFooterPreventClose});let f=r.view.dom.querySelector(`.tiptap-page-footer[data-footer-page-number="${n}"]`);return f&&(f.dataset.editing="true"),a.isVisible()||(s.wasEditable=r.isEditable),r.setEditable(!1),s.activeEditor=l.getEditor(),s.activeEditorType="footer",s.activePageNumber=n,r.emit("update",{editor:r,transaction:r.state.tr,appendedTransactions:[]}),!0}var eQ=new WeakMap,e0=class{getNodesOnPage(e,t){return this.getAllNodesWithPages(t).filter(t=>t.page===e)}getPageForPosition(e,t,o=!1){let n=t.dom,r=n.querySelector("[data-tiptap-pagination]");if(o&&console.log(`[PageTracker] getPageForPosition - pos: ${e}, paginationContainer found:`,!!r),!r)return o&&console.log("[PageTracker] No pagination container, returning page 1"),1;let i=this.getPageBreakPositions(n,r);if(o&&console.log("[PageTracker] Page break positions:",i),!i.length)return o&&console.log("[PageTracker] No page breaks, returning page 1"),1;let s=this.calculatePageForPosition(e,i,t,n,o);return o&&console.log(`[PageTracker] Calculated page: ${s}`),s}getCurrentPage(e,t=!1){let{from:o}=e.state.selection;t&&console.log(`[PageTracker] getCurrentPage - cursor position: ${o}`);let n=this.getPageForPosition(o,e,t);return t&&console.log(`[PageTracker] getCurrentPage - calculated page: ${n}`),n}getPageCount(e){let t=e.dom.querySelector("[data-tiptap-pagination]");return t&&t.querySelectorAll(".tiptap-page-footer").length||1}getPages(e){let t=this.getAllNodesWithPages(e),o=new Set;for(let e of t)o.add(e.page);return Array.from(o).sort((e,t)=>e-t)}doesRangeSpanPages(e,t,o){let n=this.getPageForPosition(e,o),r=this.getPageForPosition(t,o);if(n===r)return{spans:!1,pages:[n]};let i=[];for(let e=n;e<=r;e++)i.push(e);return{spans:!0,pages:i}}getPageStats(e){let t=this.getPageCount(e),o=this.getAllNodesWithPages(e),n={};for(let e of o)n[e.page]=(n[e.page]||0)+1;let r=o.length;return{totalPages:t,totalNodes:r,nodesPerPage:n,averageNodesPerPage:Math.round(100*(t>0?r/t:0))/100}}getAllNodesWithPages(e){let t=eQ.get(e.state);if(t)return t;let o=[],n=e.dom,r=n.querySelector("[data-tiptap-pagination]");if(!r)return e.state.doc.descendants((e,t)=>(e.isBlock&&o.push({node:e,pos:t,page:1}),!0)),eQ.set(e.state,o),o;let i=this.getPageBreakPositions(n,r);if(!i.length)return e.state.doc.descendants((e,t)=>(e.isBlock&&o.push({node:e,pos:t,page:1}),!0)),eQ.set(e.state,o),o;e.state.doc.descendants((t,r)=>{if(!t.isBlock)return!0;let s=this.calculateNodePage(t,r,i,e,n);return o.push({node:t,pos:r,page:s}),!1});let s=o.sort((e,t)=>e.pos-t.pos);return eQ.set(e.state,s),s}getClosestNodeOnSamePage(e,t){let o=this.getPageForPosition(e,t),n=this.getNodesOnPage(o,t);if(0===n.length)return;let r=n[0],i=Math.abs(r.pos-e);for(let t of n){let o=Math.abs(t.pos-e);o<i&&(i=o,r=t)}return r}getPageBreakPositions(e,t){let o=Array.from(t.querySelectorAll(".tiptap-page-footer"));if(o.length<=1)return[];let n=ed(e),r=e.getBoundingClientRect();return o.slice(0,-1).map(t=>(t.getBoundingClientRect().bottom-r.top)/n+e.scrollTop)}calculatePageForPosition(e,t,o,n,r=!1){try{let i=ed(n),s=o.coordsAtPos(e),a=n.getBoundingClientRect(),l=(s.top-a.top)/i+n.scrollTop;r&&console.log(`[PageTracker] calculatePageForPosition - pos: ${e}, positionTop: ${l}, pageBreakBottoms:`,t);let d=1;for(let e=0;e<t.length;e++)if(l>=t[e])d=e+2,r&&console.log(`[PageTracker] positionTop ${l} >= pageBreakBottom[${e}] ${t[e]}, page = ${d}`);else{r&&console.log(`[PageTracker] positionTop ${l} < pageBreakBottom[${e}] ${t[e]}, stopping at page ${d}`);break}return r&&console.log(`[PageTracker] Final calculated page: ${d}`),d}catch(n){return r&&console.log(`[PageTracker] Error getting coordinates for pos ${e}, using fallback:`,n),this.estimatePageForPosition(e,t,o)}}calculateNodePage(e,t,o,n,r,i=!1){try{let e=ed(r),s=n.coordsAtPos(t),a=r.getBoundingClientRect(),l=(s.top-a.top)/e+r.scrollTop;i&&console.log(`[PageTracker] calculateNodePage - pos: ${t}, nodeTop: ${l}, pageBreakBottoms:`,o);let d=1;for(let e=0;e<o.length;e++)if(l>=o[e])d=e+2,i&&console.log(`[PageTracker] nodeTop ${l} >= pageBreakBottom[${e}] ${o[e]}, page = ${d}`);else{i&&console.log(`[PageTracker] nodeTop ${l} < pageBreakBottom[${e}] ${o[e]}, stopping at page ${d}`);break}return i&&console.log(`[PageTracker] Final calculated page: ${d}`),d}catch(r){return i&&console.log(`[PageTracker] Error getting coordinates for pos ${t}, using fallback:`,r),this.estimateNodePage(e,t,o,n)}}estimatePageForPosition(e,t,o){let n=o.dom.scrollHeight,r=e/o.state.doc.content.size*n,i=1;for(let e=0;e<t.length&&r>=t[e];e++)i=e+2;return i}estimateNodePage(e,t,o,n){let r=n.dom.scrollHeight,i=t/n.state.doc.content.size*r,s=1;for(let e=0;e<o.length&&i>=o[e];e++)s=e+2;return s}};function e1(e){let t=e.extensionManager.extensions.find(e=>"collaboration"===e.name);if(!t)return{isCollaborative:!1,field:"default",ydoc:null};let o=t.options;return{isCollaborative:!0,field:o.field||"default",ydoc:o.document||null}}function e2(e){let t=e.extensionManager.extensions.find(e=>"collaborationCaret"===e.name||"collaborationCursor"===e.name);if(!t)return null;let o=t.options;return o.provider?{provider:o.provider,user:o.user}:null}function e4(e,t,o){return`${e}_${o}_${t}`}var e6="endnotes-change";function e5(e){var t,o;let{editor:n,options:r,storage:i,overlay:l}=e;if(!i.endnotesEnabled)return;let h=e1(n),u=e2(n),g=null==(t=r.endnotes)?void 0:t.extensions,c,f;if("function"==typeof g){let e=g({isCollaborative:h.isCollaborative,ydoc:h.ydoc,field:e4(h.field,"endnotes","default"),cursor:u});c=e.length>0?e:[s.ConvertKit];let t=g({isCollaborative:!1,ydoc:null,field:e4(h.field,"endnotes","default"),cursor:null});f=t.length>0?t:[s.ConvertKit]}else f=c=g&&g.length>0?g:[s.ConvertKit];let v=ey({...r,pageFormat:i.pageFormat}),b=Math.max(0,v.width-v.margins.left-v.margins.right);l.configure({storyExtensions:[...c,a,k],measurementExtensions:f,isCollaborative:h.isCollaborative,offscreenContentWidth:b}),l.eagerlyCreate(),m=(e,t)=>l.cloneEndnote(e,t);let y=null==(o=r.endnotes)?void 0:o.initialContent;if(!h.isCollaborative&&y&&Object.keys(y).length>0){let e=p({references:d(n.state.doc),knownIds:Object.keys(y)});l.setEndnotesContent(e,y)}let C=l.getEditor();C&&(i.endnotesEditorOn=C.on.bind(C),i.endnotesEditorOff=C.off.bind(C)),function(e){let{editor:t,storage:o,overlay:n}=e,r=null,i=()=>{let e={},i={};for(let t of n.getStoryNoteIds()){let o=n.getEndnoteJSONById(t),r=n.getEndnoteHTMLById(t);o&&(e[t]=o),null!==r&&(i[t]=r)}o.endnotesJSON=e,o.endnotesHTML=i,null===r&&(r=requestAnimationFrame(()=>{r=null,t.isDestroyed||t.view.dispatch(t.view.state.tr.setMeta(e6,Date.now()))}))};n.setPersistentUpdateListener(i),i()}({editor:n,storage:i,overlay:l})}function e3(e){var t,o;let n,r,{editor:i,options:s,storage:a}=e;if(!a.endnotesEnabled||i.isDestroyed)return!1;let l=!1,p=h(d(i.state.doc));return t=a.endnoteNumbers,o=p,n=Object.keys(t),r=Object.keys(o),n.length===r.length&&n.every(e=>t[e]===o[e])||(a.endnoteNumbers=p,i.view.dispatch(i.view.state.tr.setMeta(e6,Date.now())),l=!0),ew({view:i.view,options:s,storage:a})!==eg(i.view)&&(i.view.dispatch(i.view.state.tr.setMeta(eH,Date.now())),l=!0),l}var e9="footnotes-change";function e7(e){var t,o;let{editor:n,options:r,storage:i,overlay:a}=e;if(!i.footnotesEnabled)return;let l=e1(n),d=e2(n),h=null==(t=r.footnotes)?void 0:t.extensions,p,u;if("function"==typeof h){let e=h({isCollaborative:l.isCollaborative,ydoc:l.ydoc,field:e4(l.field,"footnotes","default"),cursor:d});p=e.length>0?e:[s.ConvertKit];let t=h({isCollaborative:!1,ydoc:null,field:e4(l.field,"footnotes","default"),cursor:null});u=t.length>0?t:[s.ConvertKit]}else u=p=h&&h.length>0?h:[s.ConvertKit];let g=ey({...r,pageFormat:i.pageFormat}),c=Math.max(0,g.width-g.margins.left-g.margins.right);a.configure({storyExtensions:[...p,y,B],measurementExtensions:u,isCollaborative:l.isCollaborative,offscreenContentWidth:c}),a.eagerlyCreate(),T=(e,t)=>a.cloneFootnote(e,t);let f=null==(o=r.footnotes)?void 0:o.initialContent;if(!l.isCollaborative&&f&&Object.keys(f).length>0){let e=H({references:w(n.state.doc),knownIds:Object.keys(f)});a.setFootnotesContent(e,f)}let m=a.getEditor();m&&(i.footnotesEditorOn=m.on.bind(m),i.footnotesEditorOff=m.off.bind(m)),function(e){let{editor:t,storage:o,overlay:n}=e,r=null,i=()=>{let e={},i={};for(let t of n.getStoryNoteIds()){let o=n.getFootnoteJSONById(t),r=n.getFootnoteHTMLById(t);o&&(e[t]=o),null!==r&&(i[t]=r)}o.footnotesJSON=e,o.footnotesHTML=i,null===r&&(r=requestAnimationFrame(()=>{r=null,t.isDestroyed||t.view.dispatch(t.view.state.tr.setMeta(e9,Date.now()))}))};n.setPersistentUpdateListener(i),i()}({editor:n,storage:i,overlay:a})}function e8(e){var t,o;let n,r,{editor:i,options:s,storage:a}=e;if(!a.footnotesEnabled||i.isDestroyed)return!1;let l=w(i.state.doc),d=E(l),h=a.getPageForPosition,p=function(e){var t;let o={};for(let n of e.references){let r=e.getPageForPosition(n.pos),i=null!=(t=o[r])?t:[];i.includes(n.noteId)||i.push(n.noteId),o[r]=i}return o}({references:l,getPageForPosition:e=>h?h(e):1}),u=q.getInstance(),g=ey({...s,pageFormat:a.pageFormat}),c=Math.max(0,Math.max(0,g.width-g.margins.left-g.margins.right)-24),f=a.footnotesMaxHeightRatio*(g.height-g.margins.top-g.margins.bottom),m={};for(let[e,t]of Object.entries(p)){let o=Number(e),n=function(e){let{editor:t,pageNumber:o,idsOnPage:n}=e,r=t.view.dom.querySelector(`.tiptap-page-footnotes[data-footnotes-page-number="${o}"]`);if(!(r instanceof HTMLElement))return null;let i=[];for(let e of r.querySelectorAll(".tiptap-page-footnote"))e instanceof HTMLElement&&e.dataset.noteId&&i.push(e.dataset.noteId);let s=[...i].sort(),a=[...n].sort();if(s.length!==a.length||s.some((e,t)=>e!==a[t]))return null;let l=ed(r),d=r.getBoundingClientRect().top,h=d;for(let e of r.children){let t=e.getBoundingClientRect().bottom;t>h&&(h=t)}return(h-d)/l+4}({editor:i,pageNumber:o,idsOnPage:t});if(null!==n){m[o]=Math.min(n,f);continue}let r=14*!!a.footnotesSeparator;for(let e of t)r+=function(e){var t;let{storage:o,overlay:n,noteId:r,width:i}=e,s=null!=(t=o.footnotesHTML[r])?t:"",a=o.footnoteHeightCache.get(r);if(a&&a.html===s&&a.width===i)return a.height;let l=o.footnotesJSON[r],d=l?n.measureContentHeight(l,i):18;return o.footnoteHeightCache.set(r,{html:s,height:d,width:i}),d}({storage:a,overlay:u,noteId:e,width:c})+4;m[o]=Math.min(r,f)}return te(a.footnoteNumbers,d)&&(t=a.footnotePageAssignments,o=p,n=Object.keys(t),r=Object.keys(o),n.length===r.length&&n.every(e=>{let n=t[Number(e)],r=o[Number(e)];return Array.isArray(r)&&n.length===r.length&&n.every((e,t)=>e===r[t])}))&&te(a.footnoteAreaHeights,m)?(a.footnoteSyncRounds=0,!1):(a.footnoteSyncRounds+=1,a.footnoteSyncRounds>5?(console.warn("[Pages] Footnotes layout did not stabilize; keeping last assignment."),a.footnoteSyncRounds=0,!1):(a.footnoteNumbers=d,a.footnotePageAssignments=p,a.footnoteAreaHeights=m,eM({view:i.view,options:s,storage:a}),i.view.dispatch(i.view.state.tr.setMeta(e9,Date.now())),!0))}function te(e,t){let o=Object.keys(e),n=Object.keys(t);return o.length===n.length&&o.every(o=>e[o]===t[o])}function tt(e){return"number"==typeof e&&Number.isFinite(e)}function to(e){return tt(e)&&e>=0}function tn(e){return("string"==typeof e?Object.hasOwn(ef,e)?{valid:!0}:{valid:!1,code:"UNKNOWN_PRESET",message:`Unknown page format preset: ${e}`}:function(e){var t,o,n;if(!e||"object"!=typeof e)return{valid:!1,code:"INVALID_TYPE",message:"Expected a page format object."};if("string"!=typeof e.id||0===e.id.trim().length)return{valid:!1,code:"INVALID_ID",message:"Page format id must be a non-empty string."};if(!(tt(t=e.width)&&t>0))return{valid:!1,code:"INVALID_WIDTH",message:"Page width must be a positive finite number (pixels)."};if(!(tt(o=e.height)&&o>0))return{valid:!1,code:"INVALID_HEIGHT",message:"Page height must be a positive finite number (pixels)."};if(!((n=e.margins)&&"object"==typeof n&&to(n.top)&&to(n.right)&&to(n.bottom)&&to(n.left)))return{valid:!1,code:"INVALID_MARGINS",message:"Margins must be an object with non-negative finite numbers for top, right, bottom, and left (pixels)."};let r=e.width-(e.margins.left+e.margins.right),i=e.height-(e.margins.top+e.margins.bottom);return r<=0||i<=0?{valid:!1,code:"NEGATIVE_CONTENT_SIZE",message:"Sum of horizontal or vertical margins exceeds page dimensions, leaving no content area."}:{valid:!0}}(e)).valid}var tr="header-change",ti="footer-change",ts=["default","first","odd","even"];function ta(e){let t=e.options.headerFooterExtensions;if("function"==typeof t)return o=>{let n=t({editorType:e.editorType,subType:o,isCollaborative:e.isCollaborative,ydoc:e.ydoc,field:e4(e.collabField,e.editorType,o),cursor:e.cursor});return n.length>0?n:[s.ConvertKit]};let o=t&&t.length>0?t:[s.ConvertKit];return()=>o}function tl(e){let{editor:t,options:o,storage:n,headerOverlay:r,footerOverlay:i}=e,a=e1(t),l=e2(t),d=function(e){let t=e.headerFooterExtensions;if("function"==typeof t){let e=t({editorType:"header",subType:"default",isCollaborative:!1,ydoc:null,field:"default_default_header",cursor:null});return e.length>0?e:[s.ConvertKit]}return t&&t.length>0?t:[s.ConvertKit]}(o),h=ta({options:o,editorType:"header",collabField:a.field,ydoc:a.ydoc,isCollaborative:a.isCollaborative,cursor:l}),p=ta({options:o,editorType:"footer",collabField:a.field,ydoc:a.ydoc,isCollaborative:a.isCollaborative,cursor:l}),u=ey({...o,pageFormat:n.pageFormat}),g=Math.max(0,u.width-u.margins.left-u.margins.right);r.configure({measurementExtensions:d,extensionsResolver:h,isCollaborative:a.isCollaborative,offscreenContentWidth:g}),i.configure({measurementExtensions:d,extensionsResolver:p,isCollaborative:a.isCollaborative,offscreenContentWidth:g}),a.isCollaborative&&(a.ydoc&&function(e){let t,o,{editor:n,options:r,storage:i,ydoc:s,headerOverlay:a,footerOverlay:l}=e;i.pagesConfigMap&&i.pagesConfigMapObserver&&i.pagesConfigMap.unobserve(i.pagesConfigMapObserver);let d=s.getMap("__tiptapcollab__pages_config");i.pagesConfigMap=d;let h=(e,t)=>{void 0===d.get(e)&&d.set(e,t?"1":"0")};h("differentFirstPage",i.differentFirstPage),h("differentFirstPageFooter",i.differentFirstPageFooter),h("differentOddEven",i.differentOddEven),h("differentOddEvenFooter",i.differentOddEvenFooter),void 0===d.get("pageFormat")&&tn(i.pageFormat)&&d.set("pageFormat",i.pageFormat),void 0===d.get("pageGap")&&"number"==typeof i.pageGap&&i.pageGap>0&&d.set("pageGap",i.pageGap),void 0===d.get("headerTopMargin")&&"number"==typeof i.headerTopMargin&&d.set("headerTopMargin",i.headerTopMargin),void 0===d.get("footerBottomMargin")&&"number"==typeof i.footerBottomMargin&&d.set("footerBottomMargin",i.footerBottomMargin),i.differentFirstPage=th(d.get("differentFirstPage")),i.differentFirstPageFooter=th(d.get("differentFirstPageFooter")),i.differentOddEven=th(d.get("differentOddEven")),i.differentOddEvenFooter=th(d.get("differentOddEvenFooter")),void 0!==(t=d.get("pageFormat"))&&tn(t)&&(i.pageFormat=t),"number"==typeof(o=d.get("pageGap"))&&o>0&&(i.pageGap=o),i.headerTopMargin=tp(d.get("headerTopMargin")),i.footerBottomMargin=tp(d.get("footerBottomMargin"));let p=()=>{let e=th(d.get("differentFirstPage")),t=th(d.get("differentFirstPageFooter")),o=th(d.get("differentOddEven")),s=th(d.get("differentOddEvenFooter")),h=d.get("pageFormat"),p=d.get("pageGap"),u=tp(d.get("headerTopMargin")),g=tp(d.get("footerBottomMargin")),c=e!==i.differentFirstPage||t!==i.differentFirstPageFooter||o!==i.differentOddEven||s!==i.differentOddEvenFooter,f=void 0!==h&&tn(h)&&!function(e,t){if(e===t)return!0;if(typeof e!=typeof t||null===e||null===t||"string"==typeof e||"string"==typeof t)return!1;try{return JSON.stringify(e)===JSON.stringify(t)}catch{return!1}}(h,i.pageFormat),m="number"==typeof p&&p>0&&p!==i.pageGap,v=u!==i.headerTopMargin,b=g!==i.footerBottomMargin;(c||f||m||v||b)&&!n.isDestroyed&&(f&&(i.pageFormat=h,eb(),n.view.dispatch(n.view.state.tr.setMeta("page-format-change",Date.now())),eM({view:n.view,options:r,storage:i}),td({options:r,storage:i,headerOverlay:a,footerOverlay:l})),m&&(i.pageGap=p,eb(),n.view.dispatch(n.view.state.tr.setMeta("page-gap-change",Date.now())),eM({view:n.view,options:r,storage:i})),v&&(i.headerTopMargin=u,eb(),n.view.dispatch(n.view.state.tr.setMeta("header-top-margin-change",Date.now())),eM({view:n.view,options:r,storage:i}),tu("header",{editor:n,pagesOptions:r,storage:i,headerOverlay:a,footerOverlay:l})),b&&(i.footerBottomMargin=g,eb(),n.view.dispatch(n.view.state.tr.setMeta("footer-bottom-margin-change",Date.now())),eM({view:n.view,options:r,storage:i}),tu("footer",{editor:n,pagesOptions:r,storage:i,headerOverlay:a,footerOverlay:l})),c&&(i.differentFirstPage=e,i.differentFirstPageFooter=t,i.differentOddEven=o,i.differentOddEvenFooter=s,ek(),n.view.dispatch(n.view.state.tr.setMeta("config-sync",Date.now())),eM({view:n.view,options:r,storage:i})))};d.observe(p),i.pagesConfigMapObserver=p}({editor:t,options:o,storage:n,ydoc:a.ydoc,headerOverlay:r,footerOverlay:i}),function(e){let{editor:t,options:o,storage:n,headerOverlay:r,footerOverlay:i}=e;r.eagerlyCreateAllSubTypes(),i.eagerlyCreateAllSubTypes();let s=new Map,a=e=>{if(s.has(e))return;let o=requestAnimationFrame(()=>{if(s.delete(e),t.isDestroyed)return;ek();let o="header"===e?tr:ti,n=t.view.state.tr.setMeta(o,Date.now());t.view.dispatch(n)});s.set(e,o)},l=e=>{let t=r.getEditorForSubType(e);t&&(tg(t,n,ez(e)),a("header"))},d=e=>{let t=i.getEditorForSubType(e);t&&(tg(t,n,e$(e)),a("footer"))},h=(e,r,i)=>{let s=ez(e),l=eA(r,i.availableSpace);l!==s.getHeight(n)&&(s.setHeight(n,l),a("header"),t.isDestroyed||eM({view:t.view,options:o,storage:n}))},p=(e,r,i)=>{let s=e$(e),l=eA(r,i.availableSpace);l!==s.getHeight(n)&&(s.setHeight(n,l),a("footer"),t.isDestroyed||eM({view:t.view,options:o,storage:n}))};for(let e of ts)r.setPersistentUpdateListener(e,()=>l(e)),i.setPersistentUpdateListener(e,()=>d(e)),r.setPersistentHeightListener(e,t=>{h(e,t,eR(o,n))}),i.setPersistentHeightListener(e,t=>{p(e,t,eB(o,n))}),l(e),d(e)}({editor:t,options:o,storage:n,headerOverlay:r,footerOverlay:i}))}function td(e){let t=ey({...e.options,pageFormat:e.storage.pageFormat}),o=Math.max(0,t.width-t.margins.left-t.margins.right);e.headerOverlay.setOffscreenWidth(o),e.footerOverlay.setOffscreenWidth(o)}function th(e){return"1"===e}function tp(e){return"number"==typeof e&&Number.isFinite(e)&&e>=0?e:void 0}function tu(e,t){let{editor:o,pagesOptions:n,storage:r,headerOverlay:i,footerOverlay:s}=t,a="header"===e,l=a?i:s,d=a?eR(n,r):eB(n,r),h=!1;for(let e of ts){let t=l.getLastContentHeight(e),o=a?ez(e):e$(e),n=eA(t,d.availableSpace);n!==o.getHeight(r)&&(o.setHeight(r,n),h=!0)}h&&!o.isDestroyed&&(eM({view:o.view,options:n,storage:r}),o.view.dispatch(o.view.state.tr.setMeta(a?tr:ti,Date.now())))}function tg(e,t,o){if(e.isEmpty){o.setHTML(t,""),o.setJSON(t,{type:"doc",content:[{type:"paragraph"}]});return}o.setHTML(t,e.getHTML()),o.setJSON(t,e.getJSON())}var tc=t.Extension.create({name:"pages",addOptions:()=>({pageFormat:"A4",zoom:1,headerTopMargin:void 0,footerBottomMargin:void 0,pageGap:50,footer:"",header:"",differentFirstPage:!1,headerFirstPage:"",differentOddEven:!1,headerOdd:"",headerEven:"",differentFirstPageFooter:!1,footerFirstPage:"",differentOddEvenFooter:!1,footerOdd:"",footerEven:"",editableHeader:!0,editableFooter:!0,onPageFormatChange:()=>{},onZoomChange:()=>{},pageGapBackground:"#ffffff",accentColor:"#6366f1",headerAccentColor:void 0,footerAccentColor:void 0,toolbarGradient:!0,placeholders:void 0,footnotes:void 0,onDblClickFootnotesPreventClose:void 0,endnotes:void 0,onDblClickEndnotesPreventClose:void 0}),addExtensions:()=>[M,v],addStorage(){var e,t,o,n,r,i,s,a,l,d,h,p,u,g,c,f,m,v,b,y,C,w,E,H,T,M,O,x,P,F,k,S,N,L,I,D,z,$,R,B;let A,J;return{pageFormat:this.options.pageFormat,zoom:Math.min(4,Math.max(.25,null!=(e=this.options.zoom)?e:1)),footer:this.options.footer,header:this.options.header,headerHTML:"",pageGap:null!=(t=this.options.pageGap)?t:50,headerTopMargin:this.options.headerTopMargin,headerContentHeight:0,headerFirstPageContentHeight:0,headerOddContentHeight:0,headerEvenContentHeight:0,normalizedHeaderTemplate:null,differentFirstPage:null!=(o=this.options.differentFirstPage)&&o,headerFirstPage:null!=(n=this.options.headerFirstPage)?n:"",headerFirstPageHTML:"",normalizedFirstPageTemplate:null,differentOddEven:null!=(r=this.options.differentOddEven)&&r,headerOdd:null!=(i=this.options.headerOdd)?i:"",headerEven:null!=(s=this.options.headerEven)?s:"",headerOddHTML:"",headerEvenHTML:"",normalizedOddTemplate:null,normalizedEvenTemplate:null,footerBottomMargin:this.options.footerBottomMargin,footerHTML:"",footerContentHeight:0,footerFirstPageContentHeight:0,footerOddContentHeight:0,footerEvenContentHeight:0,normalizedFooterTemplate:null,differentFirstPageFooter:null!=(a=this.options.differentFirstPageFooter)&&a,footerFirstPage:null!=(l=this.options.footerFirstPage)?l:"",footerFirstPageHTML:"",normalizedFirstPageFooterTemplate:null,differentOddEvenFooter:null!=(d=this.options.differentOddEvenFooter)&&d,footerOdd:null!=(h=this.options.footerOdd)?h:"",footerEven:null!=(p=this.options.footerEven)?p:"",footerOddHTML:"",footerEvenHTML:"",normalizedOddFooterTemplate:null,normalizedEvenFooterTemplate:null,headerJSON:null,headerFirstPageJSON:null,headerOddJSON:null,headerEvenJSON:null,footerJSON:null,footerFirstPageJSON:null,footerOddJSON:null,footerEvenJSON:null,footnotesEnabled:null!=(g=null==(u=this.options.footnotes)?void 0:u.enabled)&&g,editableFootnotes:null==(f=null==(c=this.options.footnotes)?void 0:c.editable)||f,footnotesAccentColor:null!=(b=null!=(v=null==(m=this.options.footnotes)?void 0:m.accentColor)?v:this.options.accentColor)?b:"#6366f1",footnotesMaxHeightRatio:null!=(C=null==(y=this.options.footnotes)?void 0:y.maxHeightRatio)?C:.5,footnotesSeparator:null==(E=null==(w=this.options.footnotes)?void 0:w.separator)||E,footnotesJSON:{},footnotesHTML:{},footnoteNumbers:{},footnotePageAssignments:{},footnoteAreaHeights:{},footnotesEditorOn:null,footnotesEditorOff:null,footnoteHeightCache:new Map,footnoteSyncRounds:0,endnotesEnabled:null!=(T=null==(H=this.options.endnotes)?void 0:H.enabled)&&T,editableEndnotes:null==(O=null==(M=this.options.endnotes)?void 0:M.editable)||O,endnotesAccentColor:null!=(F=null!=(P=null==(x=this.options.endnotes)?void 0:x.accentColor)?P:this.options.accentColor)?F:"#6366f1",endnotesSeparator:null==(S=null==(k=this.options.endnotes)?void 0:k.separator)||S,endnotesJSON:{},endnotesHTML:{},endnoteNumbers:{},endnotesEditorOn:null,endnotesEditorOff:null,pageGapBackground:null!=(N=this.options.pageGapBackground)?N:"#ffffff",accentColor:null!=(L=this.options.accentColor)?L:"#6366f1",headerAccentColor:null!=(D=null!=(I=this.options.headerAccentColor)?I:this.options.accentColor)?D:"#6366f1",footerAccentColor:null!=($=null!=(z=this.options.footerAccentColor)?z:this.options.accentColor)?$:"#6366f1",editableHeader:null==(R=this.options.editableHeader)||R,editableFooter:null==(B=this.options.editableFooter)||B,uniqueId:(A=Date.now().toString(36),J=Math.random().toString(36).substring(2,9),`tiptap-pages-${A}-${J}`),styleElement:null,styleHash:null,mutationObserver:null,onAfterPageLayoutCallbacks:new Map,pageTracker:new e0,activeEditor:null,activeEditorType:null,activePageNumber:null,headerEditorOn:null,headerEditorOff:null,footerEditorOn:null,footerEditorOff:null,wasEditable:!0,cleanupDblclickHandler:null,cleanupHeaderFooterFocusHandlers:null,pagesConfigMap:null,pagesConfigMapObserver:null}},onCreate(){var e,t,o,n,r,i,s,a,l,d;let h,p,u,g,c,f,m,v,b,y,C=this.editor.view.state.tr.setMeta("unique-id-change",Date.now());this.editor.view.dispatch(C),eM({view:this.editor.view,options:this.options,storage:this.storage});let w=null!=(t=null!=(e=this.options.headerAccentColor)?e:this.options.accentColor)?t:"#6366f1",E=null!=(n=null!=(o=this.options.footerAccentColor)?o:this.options.accentColor)?n:"#6366f1",H=null==(r=this.options.toolbarGradient)||r;!function(e="#6366f1",t=!0){et=t;let o=document.getElementById(ee);if(o){o.textContent=eo(e);return}let n=document.createElement("style");n.id=ee,n.textContent=eo(e),document.head.appendChild(n)}(w,H);let T=Q.getInstance();!function(e="#6366f1",t=!0){K=t;let o=document.getElementById(W);if(o){o.textContent=_(e);return}let n=document.createElement("style");n.id=W,n.textContent=_(e),document.head.appendChild(n)}(E,H);let M=V.getInstance();tl({editor:this.editor,options:this.options,storage:this.storage,headerOverlay:T,footerOverlay:M}),i=this.editor,s=this.storage,h=(e,t,o)=>{if(!e)return;let{html:n,json:r}=T.normalize(e);t(n),o(r)},p=(e,t,o)=>{if(!e)return;let{html:n,json:r}=M.normalize(e);t(n),o(r)},h(s.header,e=>{s.headerHTML=e},e=>{s.headerJSON=e}),h(s.headerFirstPage,e=>{s.headerFirstPageHTML=e},e=>{s.headerFirstPageJSON=e}),h(s.headerOdd,e=>{s.headerOddHTML=e},e=>{s.headerOddJSON=e}),h(s.headerEven,e=>{s.headerEvenHTML=e},e=>{s.headerEvenJSON=e}),p(s.footer,e=>{s.footerHTML=e},e=>{s.footerJSON=e}),p(s.footerFirstPage,e=>{s.footerFirstPageHTML=e},e=>{s.footerFirstPageJSON=e}),p(s.footerOdd,e=>{s.footerOddHTML=e},e=>{s.footerOddJSON=e}),p(s.footerEven,e=>{s.footerEvenHTML=e},e=>{s.footerEvenJSON=e}),u=T.getEditor(),g=M.getEditor(),null==(a=s.cleanupHeaderFooterFocusHandlers)||a.call(s),u&&(s.headerEditorOn=u.on.bind(u),s.headerEditorOff=u.off.bind(u)),g&&(s.footerEditorOn=g.on.bind(g),s.footerEditorOff=g.off.bind(g)),c=s.headerEditorOn,f=s.headerEditorOff,m=s.footerEditorOn,v=s.footerEditorOff,b=()=>{let e=T.getCurrentTarget();if(!e||!i.view.dom.contains(e))return;let t=T.getCurrentPageNumber();null!==t&&("header"===s.activeEditorType&&s.activePageNumber===t||(s.activeEditor=T.getEditor(),s.activeEditorType="header",s.activePageNumber=t))},y=()=>{let e=M.getCurrentTarget();if(!e||!i.view.dom.contains(e))return;let t=M.getCurrentPageNumber();null!==t&&("footer"===s.activeEditorType&&s.activePageNumber===t||(s.activeEditor=M.getEditor(),s.activeEditorType="footer",s.activePageNumber=t))},null==c||c("focus",b),null==m||m("focus",y),s.cleanupHeaderFooterFocusHandlers=()=>{null==f||f("focus",b),null==v||v("focus",y),s.cleanupHeaderFooterFocusHandlers=null},this.storage.footnotesEnabled&&(function(e="#6366f1",t=!0){j=t;let o=document.getElementById(U);if(o){o.textContent=G(e);return}let n=document.createElement("style");n.id=U,n.textContent=G(e),document.head.appendChild(n)}(this.storage.footnotesAccentColor,H),e7({editor:this.editor,options:this.options,storage:this.storage,overlay:q.getInstance()})),this.storage.endnotesEnabled&&(function(e="#6366f1",t=!0){D=t;let o=document.getElementById(I);if(o){o.textContent=z(e);return}let n=document.createElement("style");n.id=I,n.textContent=z(e),document.head.appendChild(n)}(this.storage.endnotesAccentColor,H),e5({editor:this.editor,options:this.options,storage:this.storage,overlay:L.getInstance()})),this.storage.cleanupDblclickHandler=function(e){let{editor:t,storage:o}=e,n=t=>{let n=t.target,r="footnotes"===o.activeEditorType,i="endnotes"===o.activeEditorType,s=r||i,a="header"===o.activeEditorType||"footer"===o.activeEditorType,l=n.closest('.tiptap-page-header[data-editable="true"]');if(l){if(s)return;t.preventDefault(),t.stopPropagation(),eY({pageNumber:parseInt(l.dataset.headerPageNumber||"1",10)},e);return}let d=n.closest('.tiptap-page-footer[data-editable="true"]');if(d){if(s)return;t.preventDefault(),t.stopPropagation(),eX({pageNumber:parseInt(d.dataset.footerPageNumber||"1",10)},e);return}let h=n.closest('.tiptap-page-footnotes[data-editable="true"]');if(h instanceof HTMLElement){if(a||i)return;t.preventDefault(),t.stopPropagation();let o=parseInt(h.dataset.footnotesPageNumber||"1",10),r=n.closest(".tiptap-page-footnote");eK({pageNumber:o,focusNoteId:r instanceof HTMLElement?r.dataset.noteId:void 0},e);return}if(n.closest('.tiptap-endnotes[data-editable="true"]')instanceof HTMLElement){if(a||r)return;t.preventDefault(),t.stopPropagation();let o=n.closest(".tiptap-endnote");eW({focusNoteId:o instanceof HTMLElement?o.dataset.noteId:void 0},e)}},r=e=>{let o=e.target;if(!(o instanceof HTMLElement))return;let n=o.closest(".tiptap-footnote-ref");if(!(n instanceof HTMLElement))return;let r=n.dataset.noteId;if(!r)return;let i=t.view.dom.querySelector(`.tiptap-page-footnote[data-note-id="${r}"]`);if(!i)return;let s=i.getBoundingClientRect();window.scrollTo({top:window.scrollY+s.top-window.innerHeight/2,behavior:"smooth"})},i=e=>{let o=e.target;if(!(o instanceof HTMLElement))return;let n=o.closest(".tiptap-endnote-ref");if(!(n instanceof HTMLElement))return;let r=n.dataset.noteId;if(!r)return;let i=t.view.dom.querySelector(`.tiptap-endnote[data-note-id="${r}"]`);if(!i)return;let s=i.getBoundingClientRect();window.scrollTo({top:window.scrollY+s.top-window.innerHeight/2,behavior:"smooth"})};return t.view.dom.addEventListener("dblclick",n),t.view.dom.addEventListener("click",r),t.view.dom.addEventListener("click",i),()=>{t.view.dom.removeEventListener("dblclick",n),t.view.dom.removeEventListener("click",r),t.view.dom.removeEventListener("click",i)}}({editor:this.editor,options:this.options,storage:this.storage,headerOverlay:T,footerOverlay:M}),this.storage.getZoom=()=>this.storage.zoom,1!==this.storage.zoom&&(this.editor.view.dom.style.zoom=String(this.storage.zoom)),l=this.editor,(d=this.storage).getCurrentPage=e=>d.pageTracker.getCurrentPage(l.view,e),d.getPageForPosition=e=>d.pageTracker.getPageForPosition(e,l.view),d.getNodesOnPage=e=>d.pageTracker.getNodesOnPage(e,l.view),d.getPageStats=()=>d.pageTracker.getPageStats(l.view),d.doesRangeSpanPages=(e,t)=>d.pageTracker.doesRangeSpanPages(e,t,l.view),d.getPageCount=()=>d.pageTracker.getPageCount(l.view),d.getDistanceToNextPagebreak=e=>{let t,o=l.view.dom,n=o.querySelector("[data-tiptap-pagination]");if(!n)return null;try{t=l.view.coordsAtPos(e)}catch{return null}let r=ed(o);for(let e of Array.from(n.querySelectorAll(".tiptap-page-footer"))){let o=e.getBoundingClientRect();if(o.top>t.top)return Math.max(0,(o.top-t.bottom)/r)}return null},d.getDistanceToPrevPagebreak=e=>{let t,o=l.view.dom,n=o.querySelector("[data-tiptap-pagination]");if(!n)return null;try{t=l.view.coordsAtPos(e)}catch{return null}let r=Array.from(n.querySelectorAll(".tiptap-page-footer")),i=ed(o);for(let e=r.length-1;e>=0;e--){let o=r[e];if(!(o instanceof HTMLElement))continue;let n=o.getBoundingClientRect();if(n.bottom<t.top)return Math.max(0,(t.top-n.bottom)/i)}return null},requestAnimationFrame(()=>{requestAnimationFrame(()=>{if(this.editor.isDestroyed)return;let e=eV({view:this.editor.view,options:this.options,storage:this.storage,measureHeaderContentHeight:(e,t)=>T.measureContentHeight(e,t),measureFooterContentHeight:(e,t)=>M.measureContentHeight(e,t)});if(e.headerChanged||e.footerChanged){eM({view:this.editor.view,options:this.options,storage:this.storage});let t=this.editor.view.state.tr;e.headerChanged&&t.setMeta("header-change",Date.now()),e.footerChanged&&t.setMeta("footer-change",Date.now()),this.editor.view.dispatch(t);return}eE(this.editor.view.dom,this.storage.onAfterPageLayoutCallbacks),e8({editor:this.editor,options:this.options,storage:this.storage}),e3({editor:this.editor,options:this.options,storage:this.storage}),ew({view:this.editor.view,options:this.options,storage:this.storage})!==eg(this.editor.view)&&this.editor.view.dispatch(this.editor.view.state.tr.setMeta(eH,Date.now()))})})},addCommands(){let e=({side:e,value:t})=>{let o="header"===e;if(o?this.storage.headerTopMargin=t:this.storage.footerBottomMargin=t,this.storage.pagesConfigMap){let e=o?"headerTopMargin":"footerBottomMargin";void 0===t?this.storage.pagesConfigMap.delete(e):this.storage.pagesConfigMap.set(e,t)}eb();let n=this.editor.view.state.tr;n.setMeta(o?"header-top-margin-change":"footer-bottom-margin-change",Date.now()),this.editor.view.dispatch(n),eM({view:this.editor.view,options:this.options,storage:this.storage});let r=eV({view:this.editor.view,options:this.options,storage:this.storage});if(!(o?r.headerChanged:r.footerChanged))return;eM({view:this.editor.view,options:this.options,storage:this.storage});let i=this.editor.view.state.tr;i.setMeta(o?"header-change":"footer-change",Date.now()),this.editor.view.dispatch(i)},t=e=>{var t;let o=Q.getInstance(),n=V.getInstance(),r=o.isVisible(),i=n.isVisible(),s=this.storage.activeEditorType,a=null!=(t=this.storage.activePageNumber)?t:1;if(r&&o.hide(),i&&n.hide(),e(),!r&&!i)return;let l={editor:this.editor,options:this.options,storage:this.storage,headerOverlay:o,footerOverlay:n};"footer"===s?(r&&eY({pageNumber:a},l),i&&eX({pageNumber:a},l)):(i&&eX({pageNumber:a},l),r&&eY({pageNumber:a},l))};return{setPageFormat:e=>()=>{var t,o;if(!tn(e))return console.warn("Rejected invalid page format input. No change applied."),!1;this.storage.pageFormat=e,this.storage.pagesConfigMap&&this.storage.pagesConfigMap.set("pageFormat",e),eb();let n=this.editor.view.state.tr.setMeta("page-format-change",Date.now());return this.editor.view.dispatch(n),eM({view:this.editor.view,options:this.options,storage:this.storage}),td({options:this.options,storage:this.storage,headerOverlay:Q.getInstance(),footerOverlay:V.getInstance()}),null==(o=(t=this.options).onPageFormatChange)||o.call(t,e),!0},setZoom:e=>()=>{var t,o;let n=Math.min(4,Math.max(.25,e));this.storage.zoom=n,this.editor.view.dom.style.zoom=String(n);let r=this.editor.view.state.tr.setMeta("zoom-change",Date.now());this.editor.view.dispatch(r),null==(o=(t=this.options).onZoomChange)||o.call(t,n);let i=Q.getInstance(),s=V.getInstance();i.isVisible()&&i.updateZoom(n),s.isVisible()&&s.updateZoom(n);let a=q.getInstance();a.isVisible()&&a.updateZoom(n);let l=L.getInstance();return l.isVisible()&&l.updateZoom(n),!0},setFooter:e=>()=>{this.storage.footer=e;let t=V.getInstance();if(e){let{html:o,json:n}=t.normalize(e);this.storage.footerHTML=o,this.storage.footerJSON=n}else this.storage.footerHTML="",this.storage.footerJSON=null;ek();let o=this.editor.view.state.tr.setMeta("footer-change",Date.now());return this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setHeader:e=>()=>{this.storage.header=e;let t=Q.getInstance();if(e){let{html:o,json:n}=t.normalize(e);this.storage.headerHTML=o,this.storage.headerJSON=n}else this.storage.headerHTML="",this.storage.headerJSON=null;ek();let o=this.editor.view.state.tr.setMeta("header-change",Date.now());return this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setPageGap:e=>()=>{if("number"!=typeof e&&(e=parseInt(e,10)),e<=0)return console.warn("Page gap must be greater than 0"),!1;this.storage.pageGap=e,this.storage.pagesConfigMap&&this.storage.pagesConfigMap.set("pageGap",e),eb();let t=this.editor.view.state.tr.setMeta("page-gap-change",Date.now());return this.editor.view.dispatch(t),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setHeaderTopMargin:o=>()=>("number"!=typeof o&&(o=parseFloat(o)),Number.isNaN(o)||o<0?(console.warn("Header top margin must be >= 0"),!1):(t(()=>e({side:"header",value:o})),!0)),resetHeaderTopMargin:()=>()=>(t(()=>e({side:"header",value:void 0})),!0),setFooterBottomMargin:o=>()=>("number"!=typeof o&&(o=parseFloat(o)),Number.isNaN(o)||o<0?(console.warn("Footer bottom margin must be >= 0"),!1):(t(()=>e({side:"footer",value:o})),!0)),resetFooterBottomMargin:()=>()=>(t(()=>e({side:"footer",value:void 0})),!0),setPageGapBackground:e=>()=>{this.storage.pageGapBackground=e,eb();let t=this.editor.view.state.tr.setMeta("page-gap-background-change",Date.now());return this.editor.view.dispatch(t),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setAccentColor:e=>()=>{this.storage.accentColor=e,this.storage.headerAccentColor=e,this.storage.footerAccentColor=e,en(e),Y(e);let t=this.editor.view.state.tr.setMeta("accent-color-change",Date.now());return this.editor.view.dispatch(t),!0},setHeaderAccentColor:e=>()=>{this.storage.headerAccentColor=e,en(e);let t=this.editor.view.state.tr.setMeta("header-accent-color-change",Date.now());return this.editor.view.dispatch(t),!0},setFooterAccentColor:e=>()=>{this.storage.footerAccentColor=e,Y(e);let t=this.editor.view.state.tr.setMeta("footer-accent-color-change",Date.now());return this.editor.view.dispatch(t),!0},setDifferentFirstPage:e=>()=>(t(()=>{this.storage.differentFirstPage=e,this.storage.differentFirstPageFooter=e,this.storage.pagesConfigMap&&(this.storage.pagesConfigMap.set("differentFirstPage",e?"1":"0"),this.storage.pagesConfigMap.set("differentFirstPageFooter",e?"1":"0")),this.storage.normalizedFirstPageTemplate=null,this.storage.normalizedFirstPageFooterTemplate=null,ek();let t=this.editor.view.state.tr.setMeta("header-change",Date.now());this.editor.view.dispatch(t),eM({view:this.editor.view,options:this.options,storage:this.storage})}),!0),setHeaderFirstPage:e=>()=>{this.storage.headerFirstPage=e;let t=Q.getInstance();if(e){let{html:o,json:n}=t.normalize(e);this.storage.headerFirstPageHTML=o,this.storage.headerFirstPageJSON=n}else this.storage.headerFirstPageHTML="",this.storage.headerFirstPageJSON=null;this.storage.normalizedFirstPageTemplate=null,ek();let o=this.editor.view.state.tr.setMeta("header-change",Date.now());return this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setDifferentOddEven:e=>()=>(t(()=>{this.storage.differentOddEven=e,this.storage.differentOddEvenFooter=e;let t=null!==this.storage.pagesConfigMap;this.storage.pagesConfigMap&&(this.storage.pagesConfigMap.set("differentOddEven",e?"1":"0"),this.storage.pagesConfigMap.set("differentOddEvenFooter",e?"1":"0")),e&&!t&&(!this.storage.headerOddHTML&&this.storage.headerHTML&&(this.storage.headerOddHTML=this.storage.headerHTML,this.storage.headerOddJSON=this.storage.headerJSON),!this.storage.footerOddHTML&&this.storage.footerHTML&&(this.storage.footerOddHTML=this.storage.footerHTML,this.storage.footerOddJSON=this.storage.footerJSON)),this.storage.normalizedOddTemplate=null,this.storage.normalizedEvenTemplate=null,this.storage.normalizedOddFooterTemplate=null,this.storage.normalizedEvenFooterTemplate=null,ek();let o=this.editor.view.state.tr.setMeta("header-change",Date.now());this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage})}),!0),setHeaderOdd:e=>()=>{this.storage.headerOdd=e;let t=Q.getInstance();if(e){let{html:o,json:n}=t.normalize(e);this.storage.headerOddHTML=o,this.storage.headerOddJSON=n}else this.storage.headerOddHTML="",this.storage.headerOddJSON=null;this.storage.normalizedOddTemplate=null,ek();let o=this.editor.view.state.tr.setMeta("header-change",Date.now());return this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setHeaderEven:e=>()=>{this.storage.headerEven=e;let t=Q.getInstance();if(e){let{html:o,json:n}=t.normalize(e);this.storage.headerEvenHTML=o,this.storage.headerEvenJSON=n}else this.storage.headerEvenHTML="",this.storage.headerEvenJSON=null;this.storage.normalizedEvenTemplate=null,ek();let o=this.editor.view.state.tr.setMeta("header-change",Date.now());return this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setDifferentFirstPageFooter:e=>()=>{this.storage.differentFirstPageFooter=e,this.storage.pagesConfigMap&&this.storage.pagesConfigMap.set("differentFirstPageFooter",e?"1":"0"),this.storage.normalizedFirstPageFooterTemplate=null,ek();let t=this.editor.view.state.tr.setMeta("footer-change",Date.now());return this.editor.view.dispatch(t),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setFooterFirstPage:e=>()=>{this.storage.footerFirstPage=e;let t=V.getInstance();if(e){let{html:o,json:n}=t.normalize(e);this.storage.footerFirstPageHTML=o,this.storage.footerFirstPageJSON=n}else this.storage.footerFirstPageHTML="",this.storage.footerFirstPageJSON=null;this.storage.normalizedFirstPageFooterTemplate=null,ek();let o=this.editor.view.state.tr.setMeta("footer-change",Date.now());return this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setDifferentOddEvenFooter:e=>()=>{this.storage.differentOddEvenFooter=e,this.storage.pagesConfigMap&&this.storage.pagesConfigMap.set("differentOddEvenFooter",e?"1":"0"),this.storage.normalizedOddFooterTemplate=null,this.storage.normalizedEvenFooterTemplate=null,ek();let t=this.editor.view.state.tr.setMeta("footer-change",Date.now());return this.editor.view.dispatch(t),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setFooterOdd:e=>()=>{this.storage.footerOdd=e;let t=V.getInstance();if(e){let{html:o,json:n}=t.normalize(e);this.storage.footerOddHTML=o,this.storage.footerOddJSON=n}else this.storage.footerOddHTML="",this.storage.footerOddJSON=null;this.storage.normalizedOddFooterTemplate=null,ek();let o=this.editor.view.state.tr.setMeta("footer-change",Date.now());return this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},setFooterEven:e=>()=>{this.storage.footerEven=e;let t=V.getInstance();if(e){let{html:o,json:n}=t.normalize(e);this.storage.footerEvenHTML=o,this.storage.footerEvenJSON=n}else this.storage.footerEvenHTML="",this.storage.footerEvenJSON=null;this.storage.normalizedEvenFooterTemplate=null,ek();let o=this.editor.view.state.tr.setMeta("footer-change",Date.now());return this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},closeHeaderFooterEditors:()=>()=>{let e=Q.getInstance(),t=V.getInstance();return e.isVisible()?(e.hide(),!0):!!t.isVisible()&&(t.hide(),!0)},closeHeaderEditor:()=>()=>{let e=Q.getInstance();return!!e.isVisible()&&(e.hide(),!0)},closeFooterEditor:()=>()=>{let e=V.getInstance();return!!e.isVisible()&&(e.hide(),!0)},openHeaderEditor:e=>()=>{let t=Q.getInstance(),o=V.getInstance();return eY(e,{editor:this.editor,options:this.options,storage:this.storage,headerOverlay:t,footerOverlay:o})},openFooterEditor:e=>()=>{let t=Q.getInstance(),o=V.getInstance();return eX(e,{editor:this.editor,options:this.options,storage:this.storage,headerOverlay:t,footerOverlay:o})},setHeaderEditable:e=>()=>{this.storage.editableHeader=e;let t=Q.getInstance();if(!e&&t.isVisible())return t.hide(),!0;let o=this.editor.view.state.tr.setMeta("header-change",Date.now());return this.editor.view.dispatch(o),!0},setFooterEditable:e=>()=>{this.storage.editableFooter=e;let t=V.getInstance();if(!e&&t.isVisible())return t.hide(),!0;let o=this.editor.view.state.tr.setMeta("footer-change",Date.now());return this.editor.view.dispatch(o),!0},insertFootnote:()=>({state:e,tr:t,dispatch:o})=>{if(!this.storage.footnotesEnabled)return!1;let n=e.schema.nodes.footnoteReference;if(!n)return!1;let r=u();if(o){let e=t.selection.to;t.insert(e,n.create({noteId:r})),requestAnimationFrame(()=>{if(this.editor.isDestroyed)return;let t=w(this.editor.state.doc).findIndex(e=>e.noteId===r);q.getInstance().insertFootnoteItem(r,Math.max(0,t)),requestAnimationFrame(()=>{var t,o,n;this.editor.isDestroyed||eK({pageNumber:null!=(n=null==(o=(t=this.storage).getPageForPosition)?void 0:o.call(t,e))?n:1,focusNoteId:r},{editor:this.editor,options:this.options,storage:this.storage})})})}return!0},setFootnotes:e=>()=>{if(!this.storage.footnotesEnabled)return!1;let t=H({references:w(this.editor.state.doc),knownIds:Object.keys(e)});return q.getInstance().setFootnotesContent(t,e),!0},openFootnoteEditor:e=>()=>eK(e,{editor:this.editor,options:this.options,storage:this.storage}),closeFootnoteEditor:()=>()=>{let e=q.getInstance();return!!e.isVisible()&&(e.hide(),!0)},setFootnotesEditable:e=>()=>{this.storage.editableFootnotes=e;let t=q.getInstance();if(!e&&t.isVisible())return t.hide(),!0;let o=this.editor.view.state.tr.setMeta("footnotes-change",Date.now());return this.editor.view.dispatch(o),!0},cleanupOrphanFootnotes:()=>()=>{if(!this.storage.footnotesEnabled)return!1;let e=new Set(w(this.editor.state.doc).map(e=>e.noteId));return q.getInstance().removeOrphanItems(e)},setFootnotesAccentColor:e=>()=>{let t;this.storage.footnotesAccentColor=e,(t=document.getElementById(U))&&(t.textContent=G(e));let o=this.editor.view.state.tr.setMeta("footnotes-change",Date.now());return this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0},insertEndnote:()=>({state:e,tr:t,dispatch:o})=>{if(!this.storage.endnotesEnabled)return!1;let n=e.schema.nodes.endnoteReference;if(!n)return!1;let r=g();if(o){let e=t.selection.to;t.insert(e,n.create({noteId:r})),requestAnimationFrame(()=>{if(this.editor.isDestroyed)return;let e=d(this.editor.state.doc).findIndex(e=>e.noteId===r);L.getInstance().insertEndnoteItem(r,Math.max(0,e)),requestAnimationFrame(()=>{this.editor.isDestroyed||eW({focusNoteId:r},{editor:this.editor,options:this.options,storage:this.storage})})})}return!0},setEndnotes:e=>()=>{if(!this.storage.endnotesEnabled)return!1;let t=p({references:d(this.editor.state.doc),knownIds:Object.keys(e)});return L.getInstance().setEndnotesContent(t,e),!0},openEndnoteEditor:e=>()=>eW(null!=e?e:{},{editor:this.editor,options:this.options,storage:this.storage}),closeEndnoteEditor:()=>()=>{let e=L.getInstance();return!!e.isVisible()&&(e.hide(),!0)},setEndnotesEditable:e=>()=>{this.storage.editableEndnotes=e;let t=L.getInstance();if(!e&&t.isVisible())return t.hide(),!0;let o=this.editor.view.state.tr.setMeta("endnotes-change",Date.now());return this.editor.view.dispatch(o),!0},cleanupOrphanEndnotes:()=>()=>{if(!this.storage.endnotesEnabled)return!1;let e=new Set(d(this.editor.state.doc).map(e=>e.noteId));return L.getInstance().removeOrphanItems(e)},setEndnotesAccentColor:e=>()=>{let t;this.storage.endnotesAccentColor=e,(t=document.getElementById(I))&&(t.textContent=z(e));let o=this.editor.view.state.tr.setMeta("endnotes-change",Date.now());return this.editor.view.dispatch(o),eM({view:this.editor.view,options:this.options,storage:this.storage}),!0}}},onDestroy(){var e,t,o,n,r,i;null==(t=(e=this.storage).cleanupDblclickHandler)||t.call(e),null==(n=(o=this.storage).cleanupHeaderFooterFocusHandlers)||n.call(o),this.storage.pagesConfigMap&&this.storage.pagesConfigMapObserver&&this.storage.pagesConfigMap.unobserve(this.storage.pagesConfigMapObserver),this.storage.pagesConfigMap=null,this.storage.pagesConfigMapObserver=null,this.storage.onAfterPageLayoutCallbacks.clear(),(i=this.storage).mutationObserver&&(i.mutationObserver.disconnect(),i.mutationObserver=null),Q.destroy(),V.destroy(),T=null,q.destroy(),m=null,L.destroy(),this.editor.view.dom.style.zoom="",null!=(r=this.storage.styleElement)&&r.parentNode&&(this.storage.styleElement.parentNode.removeChild(this.storage.styleElement),this.storage.styleElement=null)},addProseMirrorPlugins(){let e=this.options,t=this.editor,r=this.storage;tl({editor:t,options:e,storage:r,headerOverlay:Q.getInstance(),footerOverlay:V.getInstance()}),r.footnotesEnabled&&e7({editor:t,options:e,storage:r,overlay:q.getInstance()}),r.endnotesEnabled&&e5({editor:t,options:e,storage:r,overlay:L.getInstance()});let i=null;return[new o.Plugin({key:new o.PluginKey("pagination"),state:{init(t,o){let i=eD({state:o,options:e,storage:r}),s=n.DecorationSet.create(o.doc,i);return eu(),s},apply(o,s,a,l){o.getMeta(eH)&&(es.length=0,ea=0,el=null);let d=ew({view:t.view,options:e,storage:r});if(d!==eg(t.view)||o.getMeta("unique-id-change")||o.getMeta("page-format-change")||o.getMeta("footer-change")||o.getMeta("header-change")||o.getMeta("footnotes-change")||o.getMeta("endnotes-change")||o.getMeta("page-gap-change")||o.getMeta("header-top-margin-change")||o.getMeta("footer-bottom-margin-change")||o.getMeta("page-gap-background-change")||o.getMeta("config-sync")){let o=eD({state:l,options:e,storage:r,pageCount:d}),s=n.DecorationSet.create(l.doc,[...o]);return eu(),null!==i&&cancelAnimationFrame(i),i=requestAnimationFrame(()=>{i=null,t.isDestroyed||(eE(t.view.dom,r.onAfterPageLayoutCallbacks),e8({editor:t,options:e,storage:r}),e3({editor:t,options:e,storage:r}))}),s}return o.docChanged&&(null!==i&&cancelAnimationFrame(i),i=requestAnimationFrame(()=>{i=null,t.isDestroyed||(ew({view:t.view,options:e,storage:r})!==eg(t.view)&&t.view.dispatch(t.view.state.tr.setMeta(eH,Date.now())),eE(t.view.dom,r.onAfterPageLayoutCallbacks),e8({editor:t,options:e,storage:r}),e3({editor:t,options:e,storage:r}))})),s}},props:{decorations(e){return this.getState(e)}}}),new o.Plugin({key:new o.PluginKey("pages-scroll-to-selection"),props:{handleScrollToSelection:e=>{if(1===r.zoom)return!1;let{from:t}=e.state.selection,o=e.domAtPos(t),n=null==o?void 0:o.node,i=(null==n?void 0:n.nodeType)===Node.TEXT_NODE?n.parentElement:n;return!!i&&(i.scrollIntoView({block:"nearest",inline:"nearest"}),!0)}}})]}});e.s(["PAGE_FORMATS",0,ef,"Pages",0,tc,"cmToPixels",0,ec,"getCollaborationField",0,e4])}]);