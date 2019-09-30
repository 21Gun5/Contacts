.386
.model flat,stdcall
option casemap:none 

include msvcrt.inc 
includelib msvcrt.lib

PERSON struct
    szName    db  32 dup(0)
    szNumber  db  32 dup(0)
PERSON ends
BOOK struct 
    count dd 0
    maxCount dd 0
    pData dd 0
BOOK ends



.const 
    pszMenu db "============",0dh,0ah,
    	" �˵����� ",0dh,0ah,
   	"1. ���Ӽ�¼",0dh,0ah,  
        "2. ɾ����¼",0dh,0ah, 
        "3. �޸ļ�¼",0dh,0ah,
        "4. ���Ҽ�¼",0dh,0ah,
      	"5. �鿴����",0dh,0ah,
        "6. �˳�����",0dh,0ah,00h
               
    pszInputTips db "ѡ���ܣ�", 00h
    pszErrorTips db "�Ƿ�����",0dh,0ah,00h
    pszErrorTips2 db "����ʧ��",0dh,0ah,00h
    pszErrorTips3 db "�ռ䲻��",0dh,0ah,00h
    pszTmp db "���ڿ�������",0dh,0ah,00h
    pszTipsAdd1 db "�û�����: ",0Ah,00h
    pszTipsAdd2 db "�û��ֻ�: ",0Ah,00h

    pszForamtD db "%d" ,00h
    pszForamtS db "%s" ,00h
    
    ;���ʱҪ����
    pszForamtD2 db "%d" ,0Ah,00h
    pszForamtS2 db "%s" ,0Ah,00h
    
    
    pszListID db "��ţ�%d",0Ah,00h
    pszListName db "������",00h
    pszListNumber db "�ֻ���",00h


.code

book_resize proc 
	;�ֶ���ջ֡������local�ֲ��������Ĭ���Զ���
    	push ebp
    	mov ebp , esp
    
    	mov ecx,[ebp+8];ecx�����һ��������book�ĵ�ַ
    	push dword ptr [ebp+0ch]; �β�maxcount��ջ����ʱ��λ��ջ����popʱ���ʵ�ָ�ֵ
    	pop [ecx+BOOK.maxCount]; ��ջ��ֵ����������ecx����book����ַ��������maxcount�����ڵ�ƫ�ƣ�popʵ�ָ�ֵ

    	; ����ѿռ�: realloc(pBook->pData, count*sizeof(PERSON))
    	mov eax , sizeof(PERSON); һ��PERSON�ṹ��Ĵ�С
    	mul dword ptr [ebp+0ch]; ���Խṹ��ĸ������õ��ܴ�С eax *= count

    	push eax; ����2: Ҫ���ٿռ���ܴ�С
    	push dword ptr [ecx+BOOK.pData] ; ����1: Դ���������Ǹ�ָ�룬ָ��ѿռ�
    	call crt_realloc; ���ú��� realloc(pBook->pData,sizeof(PERSON) * count);
    	add esp , 8
    
    	mov ecx , [ebp+08h];ecx�����һ��������book�ĵ�ַ��ecx��ʧ�ԣ������˺������ı䣬��Ҫ���»�ȡbook��ַ
    	mov [ecx+BOOK.pData] , eax; ��realloc�ķ���ֵeax(�¶ѿռ��׵�ַ)����ֵ��pBook->pData
    
    	mov eax , [ebp+0ch];ebp+cΪ����2��maxcount
    	cmp [ecx+BOOK.count] ,eax;ecx�����һ��������book�ĵ�ַ,������count�����ڵ�ƫ�ƣ��Ƚ�count��maxcount
    	jbe _RESIZE_END; �����㹻���뿪�������������Ӽ�¼�Ĳ���

    	; ���������, �ͽ�count��ֵ��pBook->count
    	; (��ΪpDataִ�еĶѿռ����������count��,���pBook->count��¼�ĸ���������ʵ�ʵĶѿռ������ɵĸ���,�ͻ�������)
    	;��Ӧ�ò����������ɣ�count��+1�ģ�maxcount��+10��
    	mov [ecx+BOOK.count],eax        
 
 _RESIZE_END:
 	;�����������ָ�ջ������
    	mov esp,ebp
    	pop ebp
    	ret 8
book_resize endp

book_add proc
	;���뺯���򿪱�ջ֡
	push ebp
    	mov ebp,esp
    	
    	push esi
    	push edi

    	mov ecx , [ebp+08h];����book��ȡ���ݣ���book�ĵ�ַ

    	; �ж��Ƿ���Ҫ������������max>count�����裬����������
    	mov eax , [ecx + BOOK.maxCount];ecxΪbook�׵�ַ������Ϊ�ֶ������ڵ�ƫ�ƣ�����Ϊbook.maxcount��ַ
    	cmp eax , [ecx + BOOK.count];���߶��ǵ�ַ��ǰ�߼Ĵ������棬��ֱ��ȡ�����ݣ������������ַ����ȡ�����ݣ�[]���������㣬����ȡ����
    	;һ��ʼ��δ��book��ֵ�����ֶ�ֵ��Ϊ0���ʲ�����ת�����ȿ���resize
    	ja _ADD1
 	; �����ǰ�������ڵ����������,˵���ռ䲻����, ��Ҫ���·���ռ�
    	add eax,0ah; ����10��
    	push eax; ����: maxcount
    	push ecx ; ���Σ�book��ַ
    	call book_resize
    	;ִ�е��˺�ADD1���Ĵ���һ����ִ�У�jxxֻ������ȥִ�У���ȻҲ���԰�����������ִ��
    	;jxx��������������ת���������Ĵ��벻ִ�У��������㣬�������ִ�У�ִ�������ȻҲ��ִ�е���Ҫ�����ǿ飨ֻҪ����ں���
    	
    	;�ռ䲻�����ʾ
    	;push offset pszErrorTips3
	;call crt_printf
	;add esp,04h
	
	;�����������ָ�ջ������
	;pop edi
    	;pop esi
    	;mov esp,ebp
    	;pop ebp
    	;ret
    
_ADD1:
    	; ��ʼ���µ���ϵ�����ӵ��绰����.
    	; ʹ�õ�ǰ������Ϊ������±�, 
    	; ��PERSON* pָ������ݿ�����������
    	; pBook->pData[pBook->count] = *p;
    	; �����׵�ַ
    	mov ecx , [ebp+08h]; ecx = pBook
    	mov edi , [ecx+BOOK.pData]; ��ϵ�������׵�ַ
    	; ��ȡ�����ڵ�ƫ��(�±�*��ϵ�˽ṹ���ֽ���)
    	mov eax , sizeof(PERSON)
    	mul [ecx + BOOK.count]; eax *= pBook->count
    	; ����Ŀ���ַ
    	add edi , eax; edi = pBook->pData + sizeof(PERSON) * pBook->count
    	; ����Դ��ַ
    	mov esi , [ebp+0ch]; esi = p
    	; ���ÿ������ֽ���
    	mov ecx , sizeof(PERSON)        ; �ܹ�����һ���ṹ��
    	; 6. �ظ�����
    	rep movsb                       ; ����
    ; ��������
    ; ++pBook->count;
    mov ecx , [ebp+08h]
    inc dword ptr [ecx+BOOK.count]  ; ����
	;����������ƽ���ջ������
    	pop edi
    	pop esi
    	mov esp,ebp
    	pop ebp
    	ret
book_add endp


main proc
	;�����ֲ�������������Ӧ��д��push��mov������ջ֡������local�����Ĭ����ˣ������Լ�д
	LOCAL menu:DWORD
	LOCAL person:PERSON
	LOCAL book:BOOK
	
SHOW_MENU:
	;��ӡ�˵���������ʾ
	push offset pszMenu
	call crt_printf
	add esp,04h
	push offset pszInputTips
	call crt_printf
	add esp,04h
	;��ȡ�û�ѡ��
	lea eax,menu
	push eax
	push offset pszForamtD
	call crt_scanf
	add esp,08h
	
	;mov eax,menu
	;push eax
	;push offset pszForamtD
	;call crt_printf
	;add esp,08h
	
	
	;����Ƿ�����ɹ����ɹ�����ת�������������Ϸ���
	cmp eax,0
	jne CHECK_INPUT
	;����ʧ������ʾ
	push offset pszErrorTips2
	call crt_printf
	add esp,04h

CHECK_INPUT:
	;>6 || <1 �����Ϸ�
	cmp dword ptr [menu] , 06h
	ja  INPUT_ERROR
	cmp dword ptr [menu] , 01h
	jb  INPUT_ERROR
	;1 <= x <= 6�Ϸ�
	jmp SELECT_FUNC

INPUT_ERROR:
	;���벻�Ϸ�
	push offset pszErrorTips
	call crt_printf
	add esp,4
	jmp SHOW_MENU 	

SELECT_FUNC:
	;������ת��
	mov eax,[menu];menu�ǵ�һ���ֲ�������menu=ebp-4�����߶��ǵ�ַ����[]Ϊȡ���ݣ����ݼ��û������1-6
	dec eax;Ҫ-1��ѡ���1-6������ת�������飬Ԫ��Ϊ0-5
	jmp [eax * 4 + jmpTable];jmpTable����ת���Ļ���ַ��eax*4Ϊ���ڵ�ƫ��
	;ѡ����Ӧ����
	jmpTable dd FUNC_ADD,FUNC_DELETE,FUNC_MODIFY,FUNC_FIND,FUNC_VIEW,FUNC_EXIT;��ת��Ϊ���飬ÿ��Ԫ�ض��Ǵ���ת�ĵ�ַ

FUNC_ADD:
	; ��ӡ��ʾ����������
	push offset pszTipsAdd1
	call crt_printf
	add esp , 4
    	lea eax , [person + PERSON.szName];personΪ����Ļ���ַ��������϶������ֶε�ƫ�Ƶ�ַ����һ���ֶ�ƫ��Ϊ0��
    	push eax
    	push offset pszForamtS
    	call crt_scanf
    	add esp , 8
    	
    	;lea eax , [person + PERSON.szName];personΪ����Ļ���ַ��������϶������ֶε�ƫ�Ƶ�ַ����һ���ֶ�ƫ��Ϊ0��
    	;push eax
    	;push offset pszForamtS
    	;call crt_printf
    	;add esp , 4
    	
   	; ��ӡ��ʾ�����պ���
    	push offset pszTipsAdd2 
    	call crt_printf
    	add esp , 4
    	lea eax , [person + PERSON.szNumber];personΪ�ڶ����ֲ�������Ϊebp-4-32-32��ƫ�Ƶ�ַΪ32��������ebp-4-32
    	push eax
    	push offset pszForamtS
    	call crt_scanf
    	add esp , 8
    	
    	;lea eax , [person + PERSON.szNumber]
    	;push eax
    	;call crt_printf
    	;add esp , 4
    	
    	; �������Ӽ�¼����
    	lea eax ,[person];�����������϶��ǵ�ַ
    	push eax;���ú���ǰ���Ƚ�����push
    	lea eax ,[book]
    	push eax
    	call book_add;��׼���ú������ɱ�������retƽ�⣻crt_printfΪC���õģ��ɵ���������add espƽ��
	;����ѭ��
	jmp SHOW_MENU
FUNC_DELETE:
	push offset pszTmp
    	call crt_printf
    	add esp , 4
    
    	jmp SHOW_MENU
FUNC_MODIFY:
    	push offset pszTmp
    	call crt_printf
    	add esp , 4
    
    	jmp SHOW_MENU
FUNC_FIND:
    	push offset pszTmp
    	call crt_printf
    	add esp , 4
    	jmp SHOW_MENU
FUNC_VIEW:
    	;mov eax,dword ptr[ebp-050h]
    	;push eax
    	;push offset pszForamtD2
    	;call crt_printf
    	;add esp,8
    	
    	;mov eax,dword ptr [ebp-050h+04h]
    	;push eax
    	;push offset pszForamtD2
    	;call crt_printf
    	;add esp,8
    	
    	
    	xor ecx,ecx;ѭ������
    	;mov edx,[ebp-050h];�ܸ���
LOOP_BODY:
    	cmp ecx,[ebp-050h]
    	push ecx; ����ecx�Ĵ�����ֵ,��Ϊ����printf�ᱻ�ĵ�
    	jae SHOW_MENU
    	;���
    	mov eax,ecx
    	add eax,01h
    	push eax
    	push offset pszListID
    	call crt_printf
    	add esp,8
    	;����
    	push offset pszListName
    	push offset pszForamtS
    	call crt_printf
    	add esp,8
    	mov eax,[ebp-050h+08h+ecx*040h]
    	push eax
    	push offset pszForamtS2
    	call crt_printf
    	add esp,8
    	;�ֻ�
    	push offset pszListNumber
    	push offset pszForamtS
    	call crt_printf
    	add esp,8
    	mov eax,[ebp-050h+08h+ecx*040h]
    	add eax,020h
    	push eax
    	push offset pszForamtS2
    	call crt_printf
    	add esp,8
    	
    	;�ı�ѭ������
    	pop ecx
    	inc ecx


    	jmp LOOP_BODY
FUNC_EXIT:
	;�˳�������
	ret
main endp 

entry:
	call main
	;�˳�����
	ret
end entry

end