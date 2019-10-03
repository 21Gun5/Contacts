;
;
; 在所有函数中, eax,ecx,edx,ebx 都被假设成易失性寄存器, 在调用每个函数的时候
; 在执行函数的过程中, 这四个寄存器的值都有可能会被改变
;
;

.386
.model flat,stdcall
option casemap:none
include msvcrt.inc
includelib msvcrt.lib

;
; 联系人结构体
;
PERSON struct
    szName    db  32 dup(0)
    szNumber  db  32 dup(0)
PERSON ends

;
; 电话本结构体. 这个结构体的C语言原型是:
; struct BOOK{
;     DWORD count;      
;     DWORD maxCount;
;     PERSON* pData
; }
; 这个结构体的操作函数有:
; 1. book_resize - 可以分配或重新修改联系人数组的大小
; 2. book_add    - 可以将新的联系人保存在联系人数组中, 如果空间不够,会自动分配空间,并更新count和maxCount
; 3. book_del    - 可以将指定下标处的联系人从联系人数组中删除. 并更新count
; 4. book_find   - 可以在联系人数组中找到包含了指定字符的联系人, 返回的是下标.
;
BOOK struct 
    count       dd 0 ; int count , 记录了当前电话本中一共有几个联系人
    maxCount    dd 0 ; int maxCount , 记录了电话本的联系人数组最大能存储多少个
    pData       dd 0 ; PERSON* pData; 联系人数组. 保存着从堆空间分配出来的内存空间首地址
BOOK ends


;
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=  只读数据段 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
;
.const 
    ; 程序菜单
    pszMenu db "1. 添加联系人",0dh,0ah, 
               "2. 删除联系人",0dh,0ah, 
               "3. 查看所有联系人",0dh,0ah, 
               "4. 查找联系人",0dh,0ah, 
               "5. 修改联系人",0dh,0ah, 
               "6. 退出",0dh,0ah, 0
    
    ; "%d"格式化控制符
    pszForamtD db "%d" , 0 
    pszForamtS db "%s" , 0 

    ; 输入提示符          
    pszInputTips    db "> ", 0  

    pszErrorTips    db "输入的数必须在1~6之间",0dh,0ah,0
    filename        db "numberbook",0
    fileflagrb      db "rb" , 0
    fileflagwb      db "wb" , 0

    pszTipsAdd1     db "请输入联系人姓名: ",0
    pszTipsAdd2     db "请输入联系人手机: ",0
    pszTipsDel      db "请输入要删除的下标: ",0
    psztipsListall  db "列出所有联系人",0dh,0ah,0
    pszListAllTitle db "序号 | 姓    名 | 联系方式",0dh,0ah,0
    pszListAllTitle2 db 30 dup("-") ,0dh,0ah,0
    pszListAllFormat db "%4d | %8s | %8s" ,0dh,0ah,0
    pszTipsFind     db "请输入姓名/手机号码: " ,0
    pszTipsUpdate   db "请输入要修改的下标: " , 0




;
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=  代码段 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
;
.code
;
; 重新修改密码本的容量
;book_resize(BOOK* pBook, int count) 
;
book_resize proc 
; [ebp+8] - BOOK* pBook
; [ebp+c] - int count
    push ebp
    mov ebp , esp
    
    mov ecx , [ebp+8]               ; ecx = pBook
    push dword ptr [ebp+0ch]        ; 形参count入栈
    pop [ecx+BOOK.maxCount]         ; 出栈赋值给最大个数

    ; 申请堆空间: realloc(pBook->pData, count*sizeof(PERSON))
    mov eax , sizeof(PERSON)        ; 一个PERSON结构体的大小
    mul dword ptr [ebp+0ch]         ; 乘以结构体的个数: eax *= count

    push eax;                       ; 传递参数2: 传入字节数
    push dword ptr [ecx+BOOK.pData] ; 传递参数1: 传入原始缓冲区
    call crt_realloc                ; 调用函数 realloc(pBook->pData,sizeof(PERSON) * count);
    add esp , 8
    
    mov ecx , [ebp+08h]             ; 得到pBook的首地址
    mov [ecx+BOOK.pData] , eax      ; 将realloc的返回值(新堆空间首地址)赋值到pBook->pData
    
    mov eax , [ebp+0ch]             ; eax = count
    cmp [ecx+BOOK.count] ,eax       ; pBook->count 和 count比较
    jbe _RESIZE_END                 ; 如果小于就离开函数

    ; 如果大于了, 就将count赋值
    ; 到pBook->count(因为pData执行的堆空间最多能容纳count个,如果pBook->count记录的个数
    ; 超过了实际的堆空间能容纳的个数,就会有问题)
    mov [ecx+BOOK.count],eax        
 
 _RESIZE_END:
    mov esp,ebp
    pop ebp
    ret 8
book_resize endp

;
; 添加号码 void book_add(BOOK* pBook, PERSON* p);
;
book_add proc
; ebp+8 - BOOK* pBook
; ebp+c - PERSON* p
    push ebp
    mov ebp , esp
    push esi
    push edi

    mov ecx , [ebp+08h]             ; ecx = pBook

    ; 判断是否需要增加容量
    mov eax , [ecx + BOOK.maxCount]
    cmp eax , [ecx + BOOK.count]    ; if(pBook->maxCount > pBook->count) 
    ja _ADD1                        ; 如果大于就跳到下面. 
    ; 如果当前容量大于等于最大容量,说明空间不够了, 需要重新分配空间
    add eax , 0ah                   ; 在最大容量的基础之上增加10个

    push eax                        ; 传参: count
    push ecx                        ; 传参: pBook
    call book_resize                ; book_resize(pBook,newCount)
    
_ADD1:
    ; 开始将新的联系人添加到电话本中.
    ; 使用当前个数作为插入的下标, 
    ; 将PERSON* p指向的内容拷贝到数组中
    ; pBook->pData[pBook->count] = *p;
    ; 1. 获取数组首地址
    mov ecx , [ebp+08h]             ; ecx = pBook
    mov edi , [ecx+BOOK.pData]      ; 联系人数组首地址
    ; 2. 获取数组内的偏移(下标*联系人结构体字节数)
    mov eax , sizeof(PERSON)
    mul [ecx + BOOK.count]          ; eax *= pBook->count
    ; 3. 设置目标地址                ; edi = pBook->pData + sizeof(PERSON) * pBook->count
    add edi , eax                   ; edi = pBook->pData + sizeof(PERSON) * pBook->count
    ; 4. 设置源地址
    mov esi , [ebp+0ch]             ; esi = p
    ; 5. 设置拷贝的字节数
    mov ecx , sizeof(PERSON)        ; 总共拷贝一个结构体
    ; 6. 重复拷贝
    rep movsb                       ; 拷贝
    
    ; 自增个数
    ; ++pBook->count;
    mov ecx , [ebp+08h]
    inc dword ptr [ecx+BOOK.count]  ; 自增

    pop edi
    pop esi
    mov esp,ebp
    pop ebp
    ret
book_add endp

;
; 删除联系人 void book_del(BOOK* pBook , unsigned int index);
; 
book_del proc
; ebp+8 - BOOK* pBook
; ebp+c - unsigned int index
    push ebp
    mov ebp, esp

    ; 判断要删除的下标是否越界
    mov ecx , [ebp+08h]
    mov eax , [ecx + BOOK.count]
    cmp [ebp+0ch],eax               ; index >= pBook->count 
    jae _DEL_END                    ; 大于等于则退出函数

    ; 使用memove来从数组中删除指定下标
    ; memmove(pBook->pData + index , pBook->pData + index + 1 , (pBook->count-index)*sizeof(PERSON) )
    ; 1. 先计算要移动的字节数
    mov ebx , [ecx + BOOK.count]    ; ebx = pBook->count
    sub ebx , [ebp+0ch]             ; ebx -= index
    mov eax,sizeof(PERSON)
    mul ebx                         ; eax *= ebx : (pBook->count-index)*sizeof(PERSON)
    
    push eax                        ; 传递参数3: 移动的大小(pBook->count-index)*sizeof(PERSON)
    mov eax , sizeof(PERSON)
    mul dword ptr[ebp+0Ch]          ; eax = sizeof(PERSON) * index
    add eax , [ecx.BOOK.pData]      ; eax = pBook->pData + index

    mov ebx , eax
    add ebx, sizeof(PERSON)         ; ebx = = pBook->pData + index + 1
    push ebx                        ; 传递参数2: 源地址:pBook->pData + index + 1
    push eax                        ; 传递参数1: 目标地址:pBook->pData + index
    call crt_memmove
    add esp , 12

    mov ecx , [ebp+08h]
    dec dword ptr [ecx+BOOK.count]  ; 递减个数

_DEL_END:
    mov esp,ebp
    pop ebp
    ret 8
book_del endp

;
; 查找函数: book_find(BOOK* pBook, const char* value , int begin)
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
    
    ; 1. 得到联系人数组的首地址
    mov edi , [esi + BOOK.pData]
    mov eax, [ebp+010h]             ; eax = begin
    imul ebx , [ebp +010h] , sizeof(PERSON) ; 计算出偏移: ebx = begin*sizeof(PERSON)
    add edi , ebx                   ; edi = pBook->pData + begin
_FIND_LOOP:
    cmp eax , [esi + BOOK.count]    ; 判断是否遍历完毕
    ja _END_FIND_LOOP
    push eax                        ; 保存eax寄存器的值(因为下面的代码会修改掉它)

    ; 2. 查找姓名是否匹配
    push dword ptr [ebp+0ch]        ; 传递参数1: value
    lea  eax , [edi + PERSON.szName]; 获取pBook.pData[i].szName的首地址
    push eax                        ; 传递参数2: pBook.pData[i].szName
    call crt_strstr                 ; strstr( pBook.pData[i].szName , value)
    add esp , 8

    cmp eax , 0
    jne _FIND_SUCCESS               ; strstr的返回结果不等于NULL,说明找到了, 跳出循环.
    
    ; 3. 查找手机号是否匹配
    push dword ptr [ebp+0ch]        ; 传递参数1: value
    lea  eax , [edi + PERSON.szNumber]; 获取pBook.pData[i].szNumber的首地址
    push eax                        ; 传递参数2: pBook.pData[i].szNumber
    call crt_strstr                 ; strstr( pBook.pData[i].szNumber , value)
    add esp , 8

    cmp eax , 0
    jne _FIND_SUCCESS               ; strstr的返回结果不等于NULL,说明找到了, 跳出循环.

    pop eax                         ; 恢复eax寄存器的值
    add edi , sizeof(PERSON)        ; 指针加一个元素
    inc eax                         ; 递增个数
    jmp _FIND_LOOP

_END_FIND_LOOP:
    mov eax , -1                    ; 循环自动退出,则说明没有找到,将返回值设置为-1  
    jmp _FIND_END
_FIND_SUCCESS:
    pop eax                         ; 回复寄存器的值
_FIND_END:
    pop edi
    pop esi
    mov esp ,ebp
    pop ebp
    ret 12
book_find endp

;
; 保存电话本到文件: book_save(BOOK*pBook);
;
book_save proc ; 
; ebp+8 : BOOK* pBook
; ebp-4 : FILE* pFile
    push ebp
    mov ebp,esp
    sub esp , 4
    ;1. 打开文件
    push offset fileflagwb          ; 传递参数2: "wb"
    push offset filename            ; 传递参数1: "numberbook"
    call crt_fopen                  ; fopen(filename, "wb")
    add esp , 8

    cmp eax , 0                     ; 判断文件是否打开成功
    je _SAVE_END                    ; 不成功,则跳转到函数结束

    mov [ebp-4] , eax               ; 保存文件指针(fopen的返回值)

    ;2. 保存个数到文件
    push eax                        ; 传递形参4: FILE*
    push 4                          ; 传递形参3: 元素字节数
    push 1                          ; 传递形参2: 元素个数
    mov ecx , [ebp+8]               ; 得到book对象首地址
    lea eax ,[ ecx + BOOK.count]    ; 得到pBook->count字段首地址
    push eax                        ; 传递形参1: 写入的数据的首地址
    call crt_fwrite                 ; fwirte(&pBook->count , 1, sizeof(int),pFile)
    add esp,16

    ;3. 保存联系人数组
    mov ecx , [ebp+8]               ; 得到book对象首地址
    push dword ptr [ebp-4]          ; 传递形参4: FILE*
    push sizeof(PERSON)             ; 传递形参3: 元素字节数
    push dword ptr[ecx+BOOK.count]  ; 传递形参2: 元素个数
    push dword ptr[ecx+BOOK.pData]  ; 传递形参1: 写入的数据的首地址
    call crt_fwrite                 ; fwirte(&pBook->pData , sizeof(PERSON), pBook->count,pFile)
    add esp,16

    ;4. 关闭文件
    push dword ptr [ebp-4]  
    call crt_fclose
    add esp , 4

_SAVE_END:
    mov esp,ebp
    pop ebp
    ret
book_save endp

;
; 将文件中的电话本加载到内存: book_load(BOOK*pBook);
;
book_load proc
; ebp+8 : BOOK* pBook
; ebp-4 : FILE* pFile
; ebp-8 : int count
    push ebp
    mov ebp,esp
    sub esp , 8
    ;1. 打开文件
    push offset fileflagrb          ; 传递参数2:"rb"
    push offset filename            ; 传递参数1:"numberbook"
    call crt_fopen                  ; fopen("numberbook","rb")
    add esp , 8

    cmp eax , 0                     ; 判断文件是否打开成功
    je _LOAD_END                    ; 不成功,则跳转到函数结束

    mov [ebp-4] , eax               ; 保存文件指针 

    ; 读取个数
    push eax                        ; 传递参数4: 文件指针
    push 4                          ; 传递参数3:
    push 1                          ; 传递参数2:
    lea eax , [ebp-8];              ; 取局部变量的地址,用于保存读取出来的联系人个数
    push eax ;                      ; 传递参数1: 保存读取出来的内容
    call crt_fread                  ;fread(&count , 1 , 4 , pFile)
    add esp , 16

    ; 重新分配大小
    push dword ptr [ebp-8]          ; 传递参数2:count
    push dword ptr [ebp+8]          ; 传递参数1:pBook 
    call book_resize                ; book_resize(pBook, count) 重新分配大小

    mov ecx ,[ebp+8]                ; ecx = pBook : 得到book对象首地址

    push dword ptr [ebp-8]          ; ebp-8 : count(从文件中读取出来的个数), 将个数保存到电话本中
    pop [ecx+BOOK.count]            ; pBook->count = count;

    ; 读取联系人数组
    push dword ptr [ebp-4]          ; 传递参数4: pFile
    push dword ptr [ebp-8]          ; 传递参数3: count
    push sizeof(PERSON)             ; 传递参数2: sizeof(PERSON)
    push dword ptr [ecx+BOOK.pData]  ; 传递参数1: pBook->pData
    call crt_fread                  ; fread(pBook->pData,sizeof(PERSON),count,pFile)
    add esp , 16

    push dword ptr [ebp-4]      ; 关闭文件
    call crt_fclose
    add esp,4

_LOAD_END:
    mov esp,ebp
    pop ebp
    ret
book_load endp



;
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=  main函数 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
;
main proc
    ; 定义局部变量
    LOCAL book          : BOOK      ; 密码本对象
    LOCAL menu          : DWORD     ; 用户接收用户输入的菜单选择
    LOCAL person        : PERSON    ; 用于接收联系人
    LOCAL index         : DWORD     ; 用于接收下标

    ; 将所有局部变量都初始化为0
    lea edi , [esp]                 ; 取得栈顶的首地址
    mov ecx , sizeof(BOOK)+4+32+32  ; 计算要初始化的大小(所有局部变量之和)
    xor eax ,eax                    ; eax的值作为填充内容
    rep stosb                       ; 开始重复将al的值填充到edi指向的内存,一个填充ecx个字节

    ; 加载密码
    lea eax , [book]
    push eax
    call book_load

    ; 开始循环
_MAIN_WHILE:
    ; 1. 打印程序功能
    push offset pszMenu             ;
    call crt_printf                 ; printf("1. 添加联系人")
    add esp , 4

    push offset pszInputTips     
    call crt_printf                 ; printf("> ")
    add esp ,4


    ; 2. 接收输入
    lea eax ,  menu                 ; 取局部变量的地址
    push eax                        ; 传递参数2: &menu
    push offset pszForamtD          ; 传递参数1: "%d"
    call crt_scanf                  ; scanf("%d" , &menu)
    add esp , 8

    cmp eax , 0                     ; 判断scanf是否成功接收输入
    jne _MAIN_CHECKINPUT            ; 等于0表示没有接收到输入,输入了错误的内容.需要清空缓冲区

    ; 提示输入错误
    push offset pszErrorTips
    call crt_printf                 ; printf("输入错误: ")
    add esp,4

_MAIN_WHILE_INPUT:
    call crt_getchar                ;
    cmp eax , 0ah                   ; while(getchar() != '\n');
    jne _MAIN_WHILE_INPUT           ; 如果接收到的字符不是'\n'则继续接收
    jmp _MAIN_WHILE

_MAIN_CHECKINPUT:
    ; 3. 判断输入是否在正确范围之内 
    cmp dword ptr [menu] , 6
    jbe  _MAIN_FUNCTION

    ; 如果大于6则输出错误提示, 并重新循环
    push offset pszErrorTips
    call crt_printf
    add esp,4
    jmp _MAIN_WHILE                 ; 跳转到循环头,重新循环


    ;
    ; 程序的主要功能
    ;
_MAIN_FUNCTION:
    mov eax , [menu]
    dec eax
    jmp [eax * 4 + jmpTable]        ; 使用跳转表跳转到指定标签

    jmpTable dd _MAIN_ADD,_MAIN_DEL,_MAIN_LISLTALL, _MAIN_FIND,_MAIN_UPDATE,_MAIN_EXIT

    ;
    ; 添加新联系人
    ;
_MAIN_ADD:  
    ; 1. 接收新联系人的姓名和手机号
    push offset pszTipsAdd1
    call crt_printf
    add esp , 4

    ; 接收姓名
    lea eax , [person + PERSON.szName]
    push eax                        ; 传递参数2: szName
    push offset pszForamtS          ; 传递参数1: "%s"
    call crt_scanf                  ; scanf("%s" , szName)
    add esp , 8
    
    ; 打印提示
    push offset pszTipsAdd2 
    call crt_printf
    add esp , 4
    
    ; 接收手机号
    lea eax , [person + PERSON.szNumber]    
    push eax                        ; 传递参数2: szNumber
    push offset pszForamtS          ; 传递参数1: "%s"
    call crt_scanf                  ; scanf("%s" , szNumber)
    add esp , 8
    
    ; 调用函数添加联系人
    lea eax ,[person]               ; 取局部变量person的地址
    push eax                        ; 传递参数2 : &person
    lea eax ,[book]                 ; 取局部变量book的地址
    push eax                        ; 传递参数1 : &book
    call book_add                   ; book_add(&book , &person)

    jmp _MAIN_WHILE 


    ;
    ; 删除联系人
    ;
_MAIN_DEL: 
    push offset pszTipsDel
    call crt_printf
    add esp , 4

    lea eax , [index]               ; 取局部变量index的地址
    push eax                        ; 传递参数2: &index
    push offset pszForamtD          ; 传递参数1: "%d"
    call crt_scanf                  ; scanf("%d" ,&index)
    add esp , 8

    cmp eax , 0
    je _MAIN_WHILE                  ; 输入有误则跳转,重新循环

    push dword ptr [index]          ; 传递参数2 : 要删除的下标
    lea eax , [book]                ; 
    push eax                        ; 传递参数1 : 密码本对象 
    call book_del                   ; book_del(&book, index);
    jmp _MAIN_LISLTALL              ; 跳转到显示所有联系人的代码


    ;
    ; 列出所有联系人
    ;
_MAIN_LISLTALL:
    ; 打印标题
    push offset pszListAllTitle
    call crt_printf
    add esp , 4

    ; 遍历电话本
    ; 循环打印联系人
    lea edi , [book]                ; 获取电话本对象首地址
    ; 得到联系人数组首地址
    mov esi , [edi+BOOK.pData]      ; esi = book.pData
    
    xor ecx,ecx
_LOOP1:
    cmp ecx , [edi + BOOK.count]    ; if ( ecx > book.count ) 
    jae _END_LOOP1                  ; 大于等于则跳出循环
    
    push ecx                        ; 保存ecx寄存器的值,因为调用printf会被改掉
    ; 打印内容
    ; printf("%d | %8s | %8s\n" , ecx , book.pData[ecx].name ,book.pData[ecx].number )
    lea eax , [esi + PERSON.szNumber]
    push eax                        ; 传递参数4: book.pData[ecx].number
    lea eax , [esi + PERSON.szName]
    push eax                        ; 传递参数3: book.pData[ecx].name
    push ecx                        ; 传递参数2: ecx
    push offset pszListAllFormat    ; 传递参数1: "%d | %8s | %8s\n" 
    call crt_printf                 ; printf("%d | %8s | %8s\n" , ecx , book.pData[ecx].name ,book.pData[ecx].number )
    add esp, 16                 

    pop ecx                         ; 恢复ecx的值
    inc ecx                         ; 递增ecx
    add esi , sizeof(PERSON)        ; 递增PERSON*
    jmp _LOOP1                      ; 再次循环
_END_LOOP1:
    push offset pszListAllTitle2
    call crt_printf
    add esp , 4
    jmp _MAIN_WHILE


    ;
    ; 查找联系人
    ;
_MAIN_FIND: 
    ; 打印菜单,接收输入
    push offset pszTipsFind
    call crt_printf
    add esp , 4

    ; 得到缓冲区的首地址
    lea eax , [person+PERSON.szNumber]
    push eax                        ; 传入参数2: person.szNumber
    push offset pszForamtS          ; 传入参数1: "%s"
    call crt_scanf                  ; scanf("%s",person.szNumber)
    add esp , 4

    ; 输出标题
    push offset pszListAllTitle2
    call crt_printf
    add esp , 4             

    mov eax , -1                    ; 作为查找的开始下标
    ; 调用查找函数
_MAIN_FIND_LOOP:
    inc eax                         ; 递增开始下标
    push eax                        ; 传递参数3 : begin
    lea eax , [person+PERSON.szNumber]
    push eax                        ; 传递参数2 : value
    lea eax , [book]
    push eax                        ; 传递参数1 : &book 
    call book_find                  ; book_find(&book,&person.szNumber,eax)
    cmp eax , -1                    ; 判断是否返回-1,如果是, 说明没有找到
    je _END_MAIN_FIND_LOOP

    push eax                        ; 保存eax的值
    mov ecx,eax
    ; 输出查找到的内容
    ; printf("%d | %8s | %8s\n" , ecx , book.pData[eax].name ,book.pData[eax].number )
    ; 1. 得到book.pData[eax]的首地址
    imul eax, eax , sizeof(PERSON)  ; eax 保存的是查找回来的下标, 现在eax *= PERSON等于数组内的字节偏移
    mov esi , [book + BOOK.pData]   ; 得到数组首地址
    add esi , eax                   ; 得到查找到的元素的首地址

    lea eax , [esi + PERSON.szNumber]
    push eax                        ; 传递参数4: book.pData[ecx].number
    lea eax , [esi + PERSON.szName]
    push eax                        ; 传递参数3: book.pData[ecx].name
    push ecx                        ; 传递参数2: ecx
    push offset pszListAllFormat; 传递参数1: "%d | %8s | %8s\n" 
    call crt_printf                 ; printf("%d | %8s | %8s\n" , edx , book.pData[ecx].name ,book.pData[ecx].number )
    add esp , 16

    pop eax                         ; 恢复eax寄存器的值
    jmp _MAIN_FIND_LOOP             ; 继续循环
_END_MAIN_FIND_LOOP:
    jmp _MAIN_WHILE

    ;
    ; 更新联系人
    ;
_MAIN_UPDATE:
    ; 1. 打印提示要修改的是第几个
    push offset pszTipsUpdate 
    call crt_printf
    add esp , 4

    lea eax , [index]               ; 取局部变量的地址
    push eax                        ; 传递参数2:&index
    push offset pszForamtD          ; 传递参数1:"%s"
    call crt_scanf                  ; scanf("%d , &index)
    add esp , 8

    cmp eax , 0                     ; 判断scanf是否调用成功
    je _MAIN_WHILE                  ; 不成功则重新循环

    ; 2. 打印修改前的联系人信息
    ; 2.1 获取对话本对象
    lea ecx,[book]
    mov esi , [ecx + BOOK.pData]    ;得到联系人数组首地址
    ; 2.2 计算删除下标在数组内的偏移
    imul eax , dword ptr [index] , sizeof(PERSON)
    add esi , eax                   ; 首地址+偏移: esi = book.pData + index 

    ; 打印修改前的姓名
    lea eax , [esi + PERSON.szName]
    push eax                        ; 传递参数1: book.pData[index].name
    call crt_printf                 ; 不用恢复栈顶,因为这个参数后面的scanf会接着用
    
    ; 接收新的姓名
    push offset pszForamtS          ; 传递参数1:"%s", 参数2由于调用crt_printf没有平衡栈,因此,参数2还在栈中,不用传递
    call crt_scanf                  ; scanf("%s" , &book.pData[ecx].name)
    add esp, 8

    ; 打印原始的
    lea eax , [esi + PERSON.szNumber]
    push eax                        ; 传递参数4: book.pData[ecx].number
    call crt_printf                 ; 不用恢复栈顶,因为这个参数后面的scanf会接着用

    push offset pszForamtS          ; 传递参数1:"%s", 参数2由于调用crt_printf没有平衡栈,因此,参数2还在栈中,不用传递
    call crt_scanf                  ; scanf("%s" , &book.pData[ecx].number)
    add esp, 8

    jmp _MAIN_WHILE

    ;
    ; 退出
    ;
_MAIN_EXIT: 
    ; 保存密码
    lea eax , [book]
    push eax
    call book_save
    ret
main endp


;
; 程序入口
;
entry:
    call main
    ret
end entry
end