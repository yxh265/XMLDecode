# XMLDecode

一个纯swift的轻量XML转成字典的类。

# 使用方法

```
xml的文件例子如：

<?xml version="1.0" encoding="ISO-8859-1"?>
<note>
<to>Tove</to>
<from>Jani</from>
<heading>Reminder</heading>
<body>Don't forget me this weekend!</body>
</note>
```

```
// 通过block的方式请求，底层会使用异步线程解码
XMLDecode().getDictionary(with: .xmlData(data: responseXML.data(using: .utf8))) { dict in
    if let note = dict?["note"] as? [String: Any] {
       print("to:", note["to"], ", from: ", note["from"])
    }
}
```

```
// 通过函数返回值的方式请求，xml的解码用主线程，如何xml太大会卡主线程
if let result = XMLDecode().getDictionary(with: .xmlData(data: data)),
   let note = result["note"] as? [String: Any] {
    print("to:", note["to"], ", from: ", note["from"])
}
```


```
请求的入参可以有url或者data
public enum XMLInfo {
    case xmlURL(url: URL?)
    case xmlData(data: Data?)
}
```
