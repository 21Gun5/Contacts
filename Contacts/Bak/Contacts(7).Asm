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
    	" 菜单导航 ",0dh,0ah,
   	"1. 添加记录",0dh,0ah,  
        "2. 删除记录",0dh,0ah, 
        "3. 修改记录",0dh,0ah,
        "4. 查找记录",0dh,0ah,
      	"5. 查看所有",0dh,0ah,
        "6. 退出程序",0dh,0ah,00h
               
    pszInputTips db "选择功能：", 00h
    pszErrorTips db "非法输入",0dh,0ah,00h
    pszErrorTips2 db "输入失败",0dh,0ah,00h
    pszErrorTips3 db "空间不足",0dh,0ah,00h
    pszTmp db "正在开发……",0dh,0ah,00h
    pszTipsAdd1 db "用户姓名: ",0Ah,00h
    pszTipsAdd2 db "用户手机: ",0Ah,00h

    pszForamtD db "%d" ,00h
    pszForamtS db "%s" ,00h
    
    ;输出时要换行
    pszForamtD2 db "%d" ,0Ah,00h
    pszForamtS2 db "%s" ,0Ah,00h
    
    
    pszListID db "序号：%d",0Ah,00h
    pszListName db "姓名：",00h
    pszListNumber db "手机：",00h


.code

book_resize proc 
	;手动打开栈帧（若有local局部变量则会默认自动打开
    	push ebp
    	mov ebp , esp
    
    	mov ecx,[ebp+8];ecx保存第一个参数，book的地址
    	push dword ptr [ebp+0ch]; 形参maxcount入栈，此时其位于栈顶，pop时便可实现赋值
    	pop [ecx+BOOK.maxCount]; 出栈赋值给最大个数，ecx保存book基地址，后面是maxcount在其内的偏移，pop实现赋值

    	; 申请堆空间: realloc(pBook->pData, count*sizeof(PERSON))
    	mov eax , sizeof(PERSON); 一个PERSON结构体的大小
    	mul dword ptr [ebp+0ch]; 乘以结构体的个数，得到总大小 eax *= count

    	push eax; 传参2: 要开辟空间的总大小
    	push dword ptr [ecx+BOOK.pData] ; 传参1: 源缓冲区，是个指针，指向堆空间
    	call crt_realloc; 调用函数 realloc(pBook->pData,sizeof(PERSON) * count);
    	add esp , 8
    
    	mov ecx , [ebp+08h];ecx保存第一个参数，book的地址（ecx易失性，调用了函数后会改变，故要重新获取book地址
    	mov [ecx+BOOK.pData] , eax; 将realloc的返回值eax(新堆空间首地址)，赋值到pBook->pData
    
    	mov eax , [ebp+0ch];ebp+c为参数2，maxcount
    	cmp [ecx+BOOK.count] ,eax;ecx保存第一个参数，book的地址,后面是count在其内的偏移，比较count和maxcount
    	jbe _RESIZE_END; 容量足够，离开函数，继续添加记录的操作

    	; 如果大于了, 就将count赋值到pBook->count
    	; (因为pData执行的堆空间最多能容纳count个,如果pBook->count记录的个数超过了实际的堆空间能容纳的个数,就会有问题)
    	;（应该不会此种情况吧，count是+1的，maxcount是+10的
    	mov [ecx+BOOK.count],eax        
 
 _RESIZE_END:
 	;函数结束：恢复栈、返回
    	mov esp,ebp
    	pop ebp
    	ret 8
book_resize endp

book_add proc
	;进入函数则开辟栈帧
	push ebp
    	mov ebp,esp
    	
    	push esi
    	push edi

    	mov ecx , [ebp+08h];参数book，取内容，是book的地址

    	; 判断是否需要增加容量，若max>count，则不需，继续存内容
    	mov eax , [ecx + BOOK.maxCount];ecx为book首地址，后面为字段在其内的偏移，最终为book.maxcount地址
    	cmp eax , [ecx + BOOK.count];二者都是地址，前者寄存器保存，可直接取出内容，后者先运算地址，再取出内容，[]内允许运算，并可取内容
    	;一开始，未对book赋值，其字段值都为0，故不可跳转，需先开辟resize
    	ja _ADD1
 	; 如果当前容量大于等于最大容量,说明空间不够了, 需要重新分配空间
    	add eax,0ah; 增加10个
    	push eax; 传参: maxcount
    	push ecx ; 传参：book地址
    	call book_resize
    	;执行到此后，ADD1处的代码一定会执行（jxx只是跳过去执行，当然也可以按照正常流程执行
    	;jxx满足条件，则跳转，其后紧跟的代码不执行，若不满足，则紧跟的执行，执行完后，自然也会执行当初要跳的那块（只要其跟在后面
    	
    	;空间不足的提示
    	;push offset pszErrorTips3
	;call crt_printf
	;add esp,04h
	
	;函数结束：恢复栈、返回
	;pop edi
    	;pop esi
    	;mov esp,ebp
    	;pop ebp
    	;ret
    
_ADD1:
    	; 开始将新的联系人添加到电话本中.
    	; 使用当前个数作为插入的下标, 
    	; 将PERSON* p指向的内容拷贝到数组中
    	; pBook->pData[pBook->count] = *p;
    	; 数组首地址
    	mov ecx , [ebp+08h]; ecx = pBook
    	mov edi , [ecx+BOOK.pData]; 联系人数组首地址
    	; 获取数组内的偏移(下标*联系人结构体字节数)
    	mov eax , sizeof(PERSON)
    	mul [ecx + BOOK.count]; eax *= pBook->count
    	; 设置目标地址
    	add edi , eax; edi = pBook->pData + sizeof(PERSON) * pBook->count
    	; 设置源地址
    	mov esi , [ebp+0ch]; esi = p
    	; 设置拷贝的字节数
    	mov ecx , sizeof(PERSON)        ; 总共拷贝一个结构体
    	; 6. 重复拷贝
    	rep movsb                       ; 拷贝
    ; 自增个数
    ; ++pBook->count;
    mov ecx , [ebp+08h]
    inc dword ptr [ecx+BOOK.count]  ; 自增
	;结束函数：平衡堆栈、返回
    	pop edi
    	pop esi
    	mov esp,ebp
    	pop ebp
    	ret
book_add endp


main proc
	;声明局部变量，本来都应该写上push、mov来开辟栈帧，若有local，则会默认如此，不必自己写
	LOCAL menu:DWORD
	LOCAL person:PERSON
	LOCAL book:BOOK
	
SHOW_MENU:
	;打印菜单及输入提示
	push offset pszMenu
	call crt_printf
	add esp,04h
	push offset pszInputTips
	call crt_printf
	add esp,04h
	;获取用户选择
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
	
	
	;检测是否输入成功，成功则跳转，继续检测输入合法性
	cmp eax,0
	jne CHECK_INPUT
	;输入失败则提示
	push offset pszErrorTips2
	call crt_printf
	add esp,04h

CHECK_INPUT:
	;>6 || <1 均不合法
	cmp dword ptr [menu] , 06h
	ja  INPUT_ERROR
	cmp dword ptr [menu] , 01h
	jb  INPUT_ERROR
	;1 <= x <= 6合法
	jmp SELECT_FUNC

INPUT_ERROR:
	;输入不合法
	push offset pszErrorTips
	call crt_printf
	add esp,4
	jmp SHOW_MENU 	

SELECT_FUNC:
	;构造跳转表
	mov eax,[menu];menu是第一个局部变量，menu=ebp-4，二者都是地址，加[]为取内容，内容即用户键入的1-6
	dec eax;要-1，选项从1-6，但跳转表是数组，元素为0-5
	jmp [eax * 4 + jmpTable];jmpTable是跳转表的基地址，eax*4为表内的偏移
	;选择相应功能
	jmpTable dd FUNC_ADD,FUNC_DELETE,FUNC_MODIFY,FUNC_FIND,FUNC_VIEW,FUNC_EXIT;跳转表为数组，每个元素都是待跳转的地址

FUNC_ADD:
	; 打印提示并接收姓名
	push offset pszTipsAdd1
	call crt_printf
	add esp , 4
    	lea eax , [person + PERSON.szName];person为对象的基地址，后面加上对象内字段的偏移地址（第一个字段偏移为0）
    	push eax
    	push offset pszForamtS
    	call crt_scanf
    	add esp , 8
    	
    	;lea eax , [person + PERSON.szName];person为对象的基地址，后面加上对象内字段的偏移地址（第一个字段偏移为0）
    	;push eax
    	;push offset pszForamtS
    	;call crt_printf
    	;add esp , 4
    	
   	; 打印提示并接收号码
    	push offset pszTipsAdd2 
    	call crt_printf
    	add esp , 4
    	lea eax , [person + PERSON.szNumber];person为第二个局部变量，为ebp-4-32-32，偏移地址为32，故最终ebp-4-32
    	push eax
    	push offset pszForamtS
    	call crt_scanf
    	add esp , 8
    	
    	;lea eax , [person + PERSON.szNumber]
    	;push eax
    	;call crt_printf
    	;add esp , 4
    	
    	; 调用添加记录函数
    	lea eax ,[person];变量名本质上都是地址
    	push eax;调用函数前，先将参数push
    	lea eax ,[book]
    	push eax
    	call book_add;标准调用函数，由被调用者ret平衡；crt_printf为C调用的，由调用者自行add esp平衡
	;继续循环
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
    	
    	lea edi , [book]                ; 获取电话本对象首地址
    	; 得到联系人数组首地址
    	mov esi , [edi+BOOK.pData]      ; esi = book.pData
    	
    	xor ecx,ecx;循环变量
    	;mov edx,[ebp-050h];总个数
LOOP_BODY:
    	cmp ecx,[ebp-050h]
    	push ecx; 保存ecx寄存器的值,因为调用printf会被改掉
    	jae SHOW_MENU
    	;序号
    	mov eax,ecx
    	add eax,01h
    	push eax
    	push offset pszListID
    	call crt_printf
    	add esp,8
    	;姓名
    	push offset pszListName
    	push offset pszForamtS
    	call crt_printf
    	add esp,8
    	mov eax,[ebp-050h+08h]
    	add eax
    	push eax
    	push offset pszForamtS2
    	call crt_printf
    	add esp,8
    	;手机
    	push offset pszListNumber
    	push offset pszForamtS
    	call crt_printf
    	add esp,8
    	mov eax,[ebp-050h+08h]
    	add eax,020h
    	add eax
    	push eax
    	push offset pszForamtS2
    	call crt_printf
    	add esp,8
    	
    	;改变循环变量
    	pop ecx
    	inc ecx


    	jmp LOOP_BODY
FUNC_EXIT:
	;退出本函数
	ret
main endp 

entry:
	call main
	;退出程序
	ret
end entry

end
