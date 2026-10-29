-- 浏览器默认样式（Chromium html.css 的相关子集）
return [[
html, body, div, section, aside, main, header, footer, p, h1, h2, h3, h4, ul, ol, li, nav, article { display: block; }
html { font-size: 16px; color: #000000; line-height: normal; }
[hidden] { display: none; }
b, strong { font-weight: bold; }
i, em { font-style: italic; }
small { font-size: smaller; }
p { margin-top: 1em; margin-bottom: 1em; }
h1 { font-size: 2em; margin-top: 0.67em; margin-bottom: 0.67em; font-weight: bold; }
h2 { font-size: 1.5em; margin-top: 0.83em; margin-bottom: 0.83em; font-weight: bold; }
h3 { font-size: 1.17em; margin-top: 1em; margin-bottom: 1em; font-weight: bold; }
button { display: inline-block; margin: 0; padding: 1px 6px; border: 2px outset #767676; background-color: #efefef; color: #000000;
  text-align: center; line-height: normal; letter-spacing: normal; text-shadow: none; cursor: default; font-size: 13.3333px; font-weight: 400; font-style: normal; }
img, canvas { display: inline; }
script, style, link, meta, title, head { display: none; }
]]
