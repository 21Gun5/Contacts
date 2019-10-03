;
;
; �����к�����, eax,ecx,edx,ebx �����������ʧ�ԼĴ���, �ڵ���ÿ��������ʱ��
; ��ִ�к����Ĺ�����, ���ĸ��Ĵ�����ֵ���п��ܻᱻ�ı�
;
;

.386
.model flat,stdcall
option casemap:none
include msvcrt.inc
includelib msvcrt.lib

;
; ��ϵ�˽ṹ��
;
PERSON struct
    szName    db  32 dup(0)
    szNumber  db  32 dup(0)
PERSON ends

;
; �绰���ṹ��. ����ṹ���C����ԭ����:
; struct BOOK{
;     DWORD count;      
;     DWORD maxCount;
;     PERSON* pData
; }
; ����ṹ��Ĳ���������:
; 1. book_resize - ���Է���������޸���ϵ������Ĵ�С
; 2. book_add    - ���Խ��µ���ϵ�˱�������ϵ��������, ����ռ䲻��,���Զ�����ռ�,������count��maxCount
; 3. book_del    - ���Խ�ָ���±괦����ϵ�˴���ϵ��������ɾ��. ������count
; 4. book_find   - ��������ϵ���������ҵ�������ָ���ַ�����ϵ��, ���ص����±�.
;
BOOK struct 
    count       dd 0 ; int count , ��¼�˵�ǰ�绰����һ���м�����ϵ��
    maxCount    dd 0 ; int maxCount , ��¼�˵绰������ϵ����������ܴ洢���ٸ�
    pData       dd 0 ; PERSON* pData; ��ϵ������. �����ŴӶѿռ����������ڴ�ռ��׵�ַ
BOOK ends


;
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=  ֻ�����ݶ� -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
;
.const 
    ; ����˵�
    pszMenu db "1. �����ϵ��",0dh,0ah, 
               "2. ɾ����ϵ��",0dh,0ah, 
               "3. �鿴������ϵ��",0dh,0ah, 
               "4. ������ϵ��",0dh,0ah, 
               "5. �޸���ϵ��",0dh,0ah, 
               "6. �˳�",0dh,0ah, 0
    
    ; "%d"��ʽ�����Ʒ�
    pszForamtD db "%d" , 0 
    pszForamtS db "%s" , 0 

    ; ������ʾ��          
    pszInputTips    db "> ", 0  

    pszErrorTips    db "�������������1~6֮��",0dh,0ah,0
    filename        db "numberbook",0
    fileflagrb      db "rb" , 0
    fileflagwb      db "wb" , 0

    pszTipsAdd1     db "��������ϵ������: ",0
    pszTipsAdd2     db "��������ϵ���ֻ�: ",0
    pszTipsDel      db "������Ҫɾ�����±�: ",0
    psztipsListall  db "�г�������ϵ��",0dh,0ah,0
    pszListAllTitle db "��� | ��    �� | ��ϵ��ʽ",0dh,0ah,0
    pszListAllTitle2 db 30 dup("-") ,0dh,0ah,0
    pszListAllFormat db "%4d | %8s | %8s" ,0dh,0ah,0
    pszTipsFind     db "����������/�ֻ�����: " ,0
    pszTipsUpdate   db "������Ҫ�޸ĵ��±�: " , 0




;
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=  ����� -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
;
.code
;
; �����޸����뱾������
;book_resize(BOOK* pBook, int count) 
;
book_resize proc 
; [ebp+8] - BOOK* pBook
; [ebp+c] - int count
    push ebp
    mov ebp , esp
    
    mov ecx , [ebp+8]               ; ecx = pBook
    push dword ptr [ebp+0ch]        ; �β�count��ջ
    pop [ecx+BOOK.maxCount]         ; ��ջ��ֵ��������

    ; ����ѿռ�: realloc(pBook->pData, count*sizeof(PERSON))
    mov eax , sizeof(PERSON)        ; һ��PERSON�ṹ��Ĵ�С
    mul dword ptr [ebp+0ch]         ; ���Խṹ��ĸ���: eax *= count

    push eax;                       ; ���ݲ���2: �����ֽ���
    push dword ptr [ecx+BOOK.pData] ; ���ݲ���1: ����ԭʼ������
    call crt_realloc                ; ���ú��� realloc(pBook->pData,sizeof(PERSON) * count);
    add esp , 8
    
    mov ecx , [ebp+08h]             ; �õ�pBook���׵�ַ
    mov [ecx+BOOK.pData] , eax      ; ��realloc�ķ���ֵ(�¶ѿռ��׵�ַ)��ֵ��pBook->pData
    
    mov eax , [ebp+0ch]             ; eax = count
    cmp [ecx+BOOK.count] ,eax       ; pBook->count �� count�Ƚ�
    jbe _RESIZE_END                 ; ���С�ھ��뿪����

    ; ���������, �ͽ�count��ֵ
    ; ��pBook->count(��ΪpDataִ�еĶѿռ����������count��,���pBook->count��¼�ĸ���
    ; ������ʵ�ʵĶѿռ������ɵĸ���,�ͻ�������)
    mov [ecx+BOOK.count],eax        
 
 _RESIZE_END:
    mov esp,ebp
    pop ebp
    ret 8
book_resize endp

;
; ��Ӻ��� void book_add(BOOK* pBook, PERSON* p);
;
book_add proc
; ebp+8 - BOOK* pBook
; ebp+c - PERSON* p
    push ebp
    mov ebp , esp
    push esi
    push edi

    mov ecx , [ebp+08h]             ; ecx = pBook

    ; �ж��Ƿ���Ҫ��������
    mov eax , [ecx + BOOK.maxCount]
    cmp eax , [ecx + BOOK.count]    ; if(pBook->maxCount > pBook->count) 
    ja _ADD1                        ; ������ھ���������. 
    ; �����ǰ�������ڵ����������,˵���ռ䲻����, ��Ҫ���·���ռ�
    add eax , 0ah                   ; ����������Ļ���֮������10��

    push eax                        ; ����: count
    push ecx                        ; ����: pBook
    call book_resize                ; book_resize(pBook,newCount)
    
_ADD1:
    ; ��ʼ���µ���ϵ����ӵ��绰����.
    ; ʹ�õ�ǰ������Ϊ������±�, 
    ; ��PERSON* pָ������ݿ�����������
    ; pBook->pData[pBook->count] = *p;
    ; 1. ��ȡ�����׵�ַ
    mov ecx , [ebp+08h]             ; ecx = pBook
    mov edi , [ecx+BOOK.pData]      ; ��ϵ�������׵�ַ
    ; 2. ��ȡ�����ڵ�ƫ��(�±�*��ϵ�˽ṹ���ֽ���)
    mov eax , sizeof(PERSON)
    mul [ecx + BOOK.count]          ; eax *= pBook->count
    ; 3. ����Ŀ���ַ                ; edi = pBook->pData + sizeof(PERSON) * pBook->count
    add edi , eax                   ; edi = pBook->pData + sizeof(PERSON) * pBook->count
    ; 4. ����Դ��ַ
    mov esi , [ebp+0ch]             ; esi = p
    ; 5. ���ÿ������ֽ���
    mov ecx , sizeof(PERSON)        ; �ܹ�����һ���ṹ��
    ; 6. �ظ�����
    rep movsb                       ; ����
    
    ; ��������
    ; ++pBook->count;
    mov ecx , [ebp+08h]
    inc dword ptr [ecx+BOOK.count]  ; ����

    pop edi
    pop esi
    mov esp,ebp
    pop ebp
    ret
book_add endp

;
; ɾ����ϵ�� void book_del(BOOK* pBook , unsigned int index);
; 
book_del proc
; ebp+8 - BOOK* pBook
; ebp+c - unsigned int index
    push ebp
    mov ebp, esp

    ; �ж�Ҫɾ�����±��Ƿ�Խ��
    mov ecx , [ebp+08h]
    mov eax , [ecx + BOOK.count]
    cmp [ebp+0ch],eax               ; index >= pBook->count 
    jae _DEL_END                    ; ���ڵ������˳�����

    ; ʹ��memove����������ɾ��ָ���±�
    ; memmove(pBook->pData + index , pBook->pData + index + 1 , (pBook->count-index)*sizeof(PERSON) )
    ; 1. �ȼ���Ҫ�ƶ����ֽ���
    mov ebx , [ecx + BOOK.count]    ; ebx = pBook->count
    sub ebx , [ebp+0ch]             ; ebx -= index
    mov eax,sizeof(PERSON)
    mul ebx                         ; eax *= ebx : (pBook->count-index)*sizeof(PERSON)
    
    push eax                        ; ���ݲ���3: �ƶ��Ĵ�С(pBook->count-index)*sizeof(PERSON)
    mov eax , sizeof(PERSON)
    mul dword ptr[ebp+0Ch]          ; eax = sizeof(PERSON) * index
    add eax , [ecx.BOOK.pData]      ; eax = pBook->pData + index

    mov ebx , eax
    add ebx, sizeof(PERSON)         ; ebx = = pBook->pData + index + 1
    push ebx                        ; ���ݲ���2: Դ��ַ:pBook->pData + index + 1
    push eax                        ; ���ݲ���1: Ŀ���ַ:pBook->pData + index
    call crt_memmove
    add esp , 12

    mov ecx , [ebp+08h]
    dec dword ptr [ecx+BOOK.count]  ; �ݼ�����

_DEL_END:
    mov esp,ebp
    pop ebp
    ret 8
book_del endp

;
; ���Һ���: book_find(BOOK* pBook, const char* value , int begin)
;
book_find proc
; ebp+8 - BOOK* pBook
; ebp+c - const char* value
; ebp+10- int begin
    push ebp
    mov ebp , esp
    push esi
    push edi
    mov esi, [ebp+08h]              ; esi = pBook
    
    ; 1. �õ���ϵ��������׵�ַ
    mov edi , [esi + BOOK.pData]
    mov eax, [ebp+010h]             ; eax = begin
    imul ebx , [ebp +010h] , sizeof(PERSON) ; �����ƫ��: ebx = begin*sizeof(PERSON)
    add edi , ebx                   ; edi = pBook->pData + begin
_FIND_LOOP:
    cmp eax , [esi + BOOK.count]    ; �ж��Ƿ�������
    ja _END_FIND_LOOP
    push eax                        ; ����eax�Ĵ�����ֵ(��Ϊ����Ĵ�����޸ĵ���)

    ; 2. ���������Ƿ�ƥ��
    push dword ptr [ebp+0ch]        ; ���ݲ���1: value
    lea  eax , [edi + PERSON.szName]; ��ȡpBook.pData[i].szName���׵�ַ
    push eax                        ; ���ݲ���2: pBook.pData[i].szName
    call crt_strstr                 ; strstr( pBook.pData[i].szName , value)
    add esp , 8

    cmp eax , 0
    jne _FIND_SUCCESS               ; strstr�ķ��ؽ��������NULL,˵���ҵ���, ����ѭ��.
    
    ; 3. �����ֻ����Ƿ�ƥ��
    push dword ptr [ebp+0ch]        ; ���ݲ���1: value
    lea  eax , [edi + PERSON.szNumber]; ��ȡpBook.pData[i].szNumber���׵�ַ
    push eax                        ; ���ݲ���2: pBook.pData[i].szNumber
    call crt_strstr                 ; strstr( pBook.pData[i].szNumber , value)
    add esp , 8

    cmp eax , 0
    jne _FIND_SUCCESS               ; strstr�ķ��ؽ��������NULL,˵���ҵ���, ����ѭ��.

    pop eax                         ; �ָ�eax�Ĵ�����ֵ
    add edi , sizeof(PERSON)        ; ָ���һ��Ԫ��
    inc eax                         ; ��������
    jmp _FIND_LOOP

_END_FIND_LOOP:
    mov eax , -1                    ; ѭ���Զ��˳�,��˵��û���ҵ�,������ֵ����Ϊ-1  
    jmp _FIND_END
_FIND_SUCCESS:
    pop eax                         ; �ظ��Ĵ�����ֵ
_FIND_END:
    pop edi
    pop esi
    mov esp ,ebp
    pop ebp
    ret 12
book_find endp

;
; ����绰�����ļ�: book_save(BOOK*pBook);
;
book_save proc ; 
; ebp+8 : BOOK* pBook
; ebp-4 : FILE* pFile
    push ebp
    mov ebp,esp
    sub esp , 4
    ;1. ���ļ�
    push offset fileflagwb          ; ���ݲ���2: "wb"
    push offset filename            ; ���ݲ���1: "numberbook"
    call crt_fopen                  ; fopen(filename, "wb")
    add esp , 8

    cmp eax , 0                     ; �ж��ļ��Ƿ�򿪳ɹ�
    je _SAVE_END                    ; ���ɹ�,����ת����������

    mov [ebp-4] , eax               ; �����ļ�ָ��(fopen�ķ���ֵ)

    ;2. ����������ļ�
    push eax                        ; �����β�4: FILE*
    push 4                          ; �����β�3: Ԫ���ֽ���
    push 1                          ; �����β�2: Ԫ�ظ���
    mov ecx , [ebp+8]               ; �õ�book�����׵�ַ
    lea eax ,[ ecx + BOOK.count]    ; �õ�pBook->count�ֶ��׵�ַ
    push eax                        ; �����β�1: д������ݵ��׵�ַ
    call crt_fwrite                 ; fwirte(&pBook->count , 1, sizeof(int),pFile)
    add esp,16

    ;3. ������ϵ������
    mov ecx , [ebp+8]               ; �õ�book�����׵�ַ
    push dword ptr [ebp-4]          ; �����β�4: FILE*
    push sizeof(PERSON)             ; �����β�3: Ԫ���ֽ���
    push dword ptr[ecx+BOOK.count]  ; �����β�2: Ԫ�ظ���
    push dword ptr[ecx+BOOK.pData]  ; �����β�1: д������ݵ��׵�ַ
    call crt_fwrite                 ; fwirte(&pBook->pData , sizeof(PERSON), pBook->count,pFile)
    add esp,16

    ;4. �ر��ļ�
    push dword ptr [ebp-4]  
    call crt_fclose
    add esp , 4

_SAVE_END:
    mov esp,ebp
    pop ebp
    ret
book_save endp

;
; ���ļ��еĵ绰�����ص��ڴ�: book_load(BOOK*pBook);
;
book_load proc
; ebp+8 : BOOK* pBook
; ebp-4 : FILE* pFile
; ebp-8 : int count
    push ebp
    mov ebp,esp
    sub esp , 8
    ;1. ���ļ�
    push offset fileflagrb          ; ���ݲ���2:"rb"
    push offset filename            ; ���ݲ���1:"numberbook"
    call crt_fopen                  ; fopen("numberbook","rb")
    add esp , 8

    cmp eax , 0                     ; �ж��ļ��Ƿ�򿪳ɹ�
    je _LOAD_END                    ; ���ɹ�,����ת����������

    mov [ebp-4] , eax               ; �����ļ�ָ�� 

    ; ��ȡ����
    push eax                        ; ���ݲ���4: �ļ�ָ��
    push 4                          ; ���ݲ���3:
    push 1                          ; ���ݲ���2:
    lea eax , [ebp-8];              ; ȡ�ֲ������ĵ�ַ,���ڱ����ȡ��������ϵ�˸���
    push eax ;                      ; ���ݲ���1: �����ȡ����������
    call crt_fread                  ;fread(&count , 1 , 4 , pFile)
    add esp , 16

    ; ���·����С
    push dword ptr [ebp-8]          ; ���ݲ���2:count
    push dword ptr [ebp+8]          ; ���ݲ���1:pBook 
    call book_resize                ; book_resize(pBook, count) ���·����С

    mov ecx ,[ebp+8]                ; ecx = pBook : �õ�book�����׵�ַ

    push dword ptr [ebp-8]          ; ebp-8 : count(���ļ��ж�ȡ�����ĸ���), ���������浽�绰����
    pop [ecx+BOOK.count]            ; pBook->count = count;

    ; ��ȡ��ϵ������
    push dword ptr [ebp-4]          ; ���ݲ���4: pFile
    push dword ptr [ebp-8]          ; ���ݲ���3: count
    push sizeof(PERSON)             ; ���ݲ���2: sizeof(PERSON)
    push dword ptr [ecx+BOOK.pData]  ; ���ݲ���1: pBook->pData
    call crt_fread                  ; fread(pBook->pData,sizeof(PERSON),count,pFile)
    add esp , 16

    push dword ptr [ebp-4]      ; �ر��ļ�
    call crt_fclose
    add esp,4

_LOAD_END:
    mov esp,ebp
    pop ebp
    ret
book_load endp



;
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=  main���� -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
;
main proc
    ; ����ֲ�����
    LOCAL book          : BOOK      ; ���뱾����
    LOCAL menu          : DWORD     ; �û������û�����Ĳ˵�ѡ��
    LOCAL person        : PERSON    ; ���ڽ�����ϵ��
    LOCAL index         : DWORD     ; ���ڽ����±�

    ; �����оֲ���������ʼ��Ϊ0
    lea edi , [esp]                 ; ȡ��ջ�����׵�ַ
    mov ecx , sizeof(BOOK)+4+32+32  ; ����Ҫ��ʼ���Ĵ�С(���оֲ�����֮��)
    xor eax ,eax                    ; eax��ֵ��Ϊ�������
    rep stosb                       ; ��ʼ�ظ���al��ֵ��䵽ediָ����ڴ�,һ�����ecx���ֽ�

    ; ��������
    lea eax , [book]
    push eax
    call book_load

    ; ��ʼѭ��
_MAIN_WHILE:
    ; 1. ��ӡ������
    push offset pszMenu             ;
    call crt_printf                 ; printf("1. �����ϵ��")
    add esp , 4

    push offset pszInputTips     
    call crt_printf                 ; printf("> ")
    add esp ,4


    ; 2. ��������
    lea eax ,  menu                 ; ȡ�ֲ������ĵ�ַ
    push eax                        ; ���ݲ���2: &menu
    push offset pszForamtD          ; ���ݲ���1: "%d"
    call crt_scanf                  ; scanf("%d" , &menu)
    add esp , 8

    cmp eax , 0                     ; �ж�scanf�Ƿ�ɹ���������
    jne _MAIN_CHECKINPUT            ; ����0��ʾû�н��յ�����,�����˴��������.��Ҫ��ջ�����

    ; ��ʾ�������
    push offset pszErrorTips
    call crt_printf                 ; printf("�������: ")
    add esp,4

_MAIN_WHILE_INPUT:
    call crt_getchar                ;
    cmp eax , 0ah                   ; while(getchar() != '\n');
    jne _MAIN_WHILE_INPUT           ; ������յ����ַ�����'\n'���������
    jmp _MAIN_WHILE

_MAIN_CHECKINPUT:
    ; 3. �ж������Ƿ�����ȷ��Χ֮�� 
    cmp dword ptr [menu] , 6
    jbe  _MAIN_FUNCTION

    ; �������6�����������ʾ, ������ѭ��
    push offset pszErrorTips
    call crt_printf
    add esp,4
    jmp _MAIN_WHILE                 ; ��ת��ѭ��ͷ,����ѭ��


    ;
    ; �������Ҫ����
    ;
_MAIN_FUNCTION:
    mov eax , [menu]
    dec eax
    jmp [eax * 4 + jmpTable]        ; ʹ����ת����ת��ָ����ǩ

    jmpTable dd _MAIN_ADD,_MAIN_DEL,_MAIN_LISLTALL, _MAIN_FIND,_MAIN_UPDATE,_MAIN_EXIT

    ;
    ; �������ϵ��
    ;
_MAIN_ADD:  
    ; 1. ��������ϵ�˵��������ֻ���
    push offset pszTipsAdd1
    call crt_printf
    add esp , 4

    ; ��������
    lea eax , [person + PERSON.szName]
    push eax                        ; ���ݲ���2: szName
    push offset pszForamtS          ; ���ݲ���1: "%s"
    call crt_scanf                  ; scanf("%s" , szName)
    add esp , 8
    
    ; ��ӡ��ʾ
    push offset pszTipsAdd2 
    call crt_printf
    add esp , 4
    
    ; �����ֻ���
    lea eax , [person + PERSON.szNumber]    
    push eax                        ; ���ݲ���2: szNumber
    push offset pszForamtS          ; ���ݲ���1: "%s"
    call crt_scanf                  ; scanf("%s" , szNumber)
    add esp , 8
    
    ; ���ú��������ϵ��
    lea eax ,[person]               ; ȡ�ֲ�����person�ĵ�ַ
    push eax                        ; ���ݲ���2 : &person
    lea eax ,[book]                 ; ȡ�ֲ�����book�ĵ�ַ
    push eax                        ; ���ݲ���1 : &book
    call book_add                   ; book_add(&book , &person)

    jmp _MAIN_WHILE 


    ;
    ; ɾ����ϵ��
    ;
_MAIN_DEL: 
    push offset pszTipsDel
    call crt_printf
    add esp , 4

    lea eax , [index]               ; ȡ�ֲ�����index�ĵ�ַ
    push eax                        ; ���ݲ���2: &index
    push offset pszForamtD          ; ���ݲ���1: "%d"
    call crt_scanf                  ; scanf("%d" ,&index)
    add esp , 8

    cmp eax , 0
    je _MAIN_WHILE                  ; ������������ת,����ѭ��

    push dword ptr [index]          ; ���ݲ���2 : Ҫɾ�����±�
    lea eax , [book]                ; 
    push eax                        ; ���ݲ���1 : ���뱾���� 
    call book_del                   ; book_del(&book, index);
    jmp _MAIN_LISLTALL              ; ��ת����ʾ������ϵ�˵Ĵ���


    ;
    ; �г�������ϵ��
    ;
_MAIN_LISLTALL:
    ; ��ӡ����
    push offset pszListAllTitle
    call crt_printf
    add esp , 4

    ; �����绰��
    ; ѭ����ӡ��ϵ��
    lea edi , [book]                ; ��ȡ�绰�������׵�ַ
    ; �õ���ϵ�������׵�ַ
    mov esi , [edi+BOOK.pData]      ; esi = book.pData
    
    xor ecx,ecx
_LOOP1:
    cmp ecx , [edi + BOOK.count]    ; if ( ecx > book.count ) 
    jae _END_LOOP1                  ; ���ڵ���������ѭ��
    
    push ecx                        ; ����ecx�Ĵ�����ֵ,��Ϊ����printf�ᱻ�ĵ�
    ; ��ӡ����
    ; printf("%d | %8s | %8s\n" , ecx , book.pData[ecx].name ,book.pData[ecx].number )
    lea eax , [esi + PERSON.szNumber]
    push eax                        ; ���ݲ���4: book.pData[ecx].number
    lea eax , [esi + PERSON.szName]
    push eax                        ; ���ݲ���3: book.pData[ecx].name
    push ecx                        ; ���ݲ���2: ecx
    push offset pszListAllFormat    ; ���ݲ���1: "%d | %8s | %8s\n" 
    call crt_printf                 ; printf("%d | %8s | %8s\n" , ecx , book.pData[ecx].name ,book.pData[ecx].number )
    add esp, 16                 

    pop ecx                         ; �ָ�ecx��ֵ
    inc ecx                         ; ����ecx
    add esi , sizeof(PERSON)        ; ����PERSON*
    jmp _LOOP1                      ; �ٴ�ѭ��
_END_LOOP1:
    push offset pszListAllTitle2
    call crt_printf
    add esp , 4
    jmp _MAIN_WHILE


    ;
    ; ������ϵ��
    ;
_MAIN_FIND: 
    ; ��ӡ�˵�,��������
    push offset pszTipsFind
    call crt_printf
    add esp , 4

    ; �õ����������׵�ַ
    lea eax , [person+PERSON.szNumber]
    push eax                        ; �������2: person.szNumber
    push offset pszForamtS          ; �������1: "%s"
    call crt_scanf                  ; scanf("%s",person.szNumber)
    add esp , 4

    ; �������
    push offset pszListAllTitle2
    call crt_printf
    add esp , 4             

    mov eax , -1                    ; ��Ϊ���ҵĿ�ʼ�±�
    ; ���ò��Һ���
_MAIN_FIND_LOOP:
    inc eax                         ; ������ʼ�±�
    push eax                        ; ���ݲ���3 : begin
    lea eax , [person+PERSON.szNumber]
    push eax                        ; ���ݲ���2 : value
    lea eax , [book]
    push eax                        ; ���ݲ���1 : &book 
    call book_find                  ; book_find(&book,&person.szNumber,eax)
    cmp eax , -1                    ; �ж��Ƿ񷵻�-1,�����, ˵��û���ҵ�
    je _END_MAIN_FIND_LOOP

    push eax                        ; ����eax��ֵ
    mov ecx,eax
    ; ������ҵ�������
    ; printf("%d | %8s | %8s\n" , ecx , book.pData[eax].name ,book.pData[eax].number )
    ; 1. �õ�book.pData[eax]���׵�ַ
    imul eax, eax , sizeof(PERSON)  ; eax ������ǲ��һ������±�, ����eax *= PERSON���������ڵ��ֽ�ƫ��
    mov esi , [book + BOOK.pData]   ; �õ������׵�ַ
    add esi , eax                   ; �õ����ҵ���Ԫ�ص��׵�ַ

    lea eax , [esi + PERSON.szNumber]
    push eax                        ; ���ݲ���4: book.pData[ecx].number
    lea eax , [esi + PERSON.szName]
    push eax                        ; ���ݲ���3: book.pData[ecx].name
    push ecx                        ; ���ݲ���2: ecx
    push offset pszListAllFormat; ���ݲ���1: "%d | %8s | %8s\n" 
    call crt_printf                 ; printf("%d | %8s | %8s\n" , edx , book.pData[ecx].name ,book.pData[ecx].number )
    add esp , 16

    pop eax                         ; �ָ�eax�Ĵ�����ֵ
    jmp _MAIN_FIND_LOOP             ; ����ѭ��
_END_MAIN_FIND_LOOP:
    jmp _MAIN_WHILE

    ;
    ; ������ϵ��
    ;
_MAIN_UPDATE:
    ; 1. ��ӡ��ʾҪ�޸ĵ��ǵڼ���
    push offset pszTipsUpdate 
    call crt_printf
    add esp , 4

    lea eax , [index]               ; ȡ�ֲ������ĵ�ַ
    push eax                        ; ���ݲ���2:&index
    push offset pszForamtD          ; ���ݲ���1:"%s"
    call crt_scanf                  ; scanf("%d , &index)
    add esp , 8

    cmp eax , 0                     ; �ж�scanf�Ƿ���óɹ�
    je _MAIN_WHILE                  ; ���ɹ�������ѭ��

    ; 2. ��ӡ�޸�ǰ����ϵ����Ϣ
    ; 2.1 ��ȡ�Ի�������
    lea ecx,[book]
    mov esi , [ecx + BOOK.pData]    ;�õ���ϵ�������׵�ַ
    ; 2.2 ����ɾ���±��������ڵ�ƫ��
    imul eax , dword ptr [index] , sizeof(PERSON)
    add esi , eax                   ; �׵�ַ+ƫ��: esi = book.pData + index 

    ; ��ӡ�޸�ǰ������
    lea eax , [esi + PERSON.szName]
    push eax                        ; ���ݲ���1: book.pData[index].name
    call crt_printf                 ; ���ûָ�ջ��,��Ϊ������������scanf�������
    
    ; �����µ�����
    push offset pszForamtS          ; ���ݲ���1:"%s", ����2���ڵ���crt_printfû��ƽ��ջ,���,����2����ջ��,���ô���
    call crt_scanf                  ; scanf("%s" , &book.pData[ecx].name)
    add esp, 8

    ; ��ӡԭʼ��
    lea eax , [esi + PERSON.szNumber]
    push eax                        ; ���ݲ���4: book.pData[ecx].number
    call crt_printf                 ; ���ûָ�ջ��,��Ϊ������������scanf�������

    push offset pszForamtS          ; ���ݲ���1:"%s", ����2���ڵ���crt_printfû��ƽ��ջ,���,����2����ջ��,���ô���
    call crt_scanf                  ; scanf("%s" , &book.pData[ecx].number)
    add esp, 8

    jmp _MAIN_WHILE

    ;
    ; �˳�
    ;
_MAIN_EXIT: 
    ; ��������
    lea eax , [book]
    push eax
    call book_save
    ret
main endp


;
; �������
;
entry:
    call main
    ret
end entry
end