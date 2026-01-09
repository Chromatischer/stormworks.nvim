" Vim script for headless stormworks image export
" Usage: nvim -S bin/stormworks-export.vim -- --script test.lua --output out.png [options]

" Get script directory
let s:script_dir = expand('<sfile>:p:h')
let s:plugin_dir = fnamemodify(s:script_dir, ':h')

" Add plugin to runtimepath
execute 'set rtp+=' . s:plugin_dir

" Parse command line arguments
let s:opts = {
  \ 'script': v:null,
  \ 'output': v:null,
  \ 'ticks': 1,
  \ 'capture': 'debug',
  \ 'inputs': {},
  \ }

let s:args = argv()
let s:i = 0
while s:i < len(s:args)
  let s:arg = s:args[s:i]
  
  if s:arg == '--script' && s:i + 1 < len(s:args)
    let s:opts.script = s:args[s:i + 1]
    let s:i += 2
  elseif s:arg == '--output' && s:i + 1 < len(s:args)
    let s:opts.output = s:args[s:i + 1]
    let s:i += 2
  elseif s:arg == '--ticks' && s:i + 1 < len(s:args)
    let s:opts.ticks = str2nr(s:args[s:i + 1])
    let s:i += 2
  elseif s:arg == '--capture' && s:i + 1 < len(s:args)
    let s:opts.capture = s:args[s:i + 1]
    let s:i += 2
  elseif s:arg == '--format' && s:i + 1 < len(s:args)
    let s:opts.format = s:args[s:i + 1]
    let s:i += 2
  elseif s:arg == '--tiles' && s:i + 1 < len(s:args)
    let s:opts.tiles = s:args[s:i + 1]
    let s:i += 2
  elseif s:arg == '--debug-canvas-size' && s:i + 1 < len(s:args)
    let s:size = matchlist(s:args[s:i + 1], '\(\d\+\)x\(\d\+\)')
    if len(s:size) >= 3
      let s:opts.debug_canvas_size = {'w': str2nr(s:size[1]), 'h': str2nr(s:size[2])}
    endif
    let s:i += 2
  elseif s:arg == '--inputs' && s:i + 1 < len(s:args)
    " Parse inputs: "B1=true,N1=0.5,N2=123"
    for s:pair in split(s:args[s:i + 1], ',')
      let s:kv = split(s:pair, '=')
      if len(s:kv) == 2
        let s:key = s:kv[0]
        let s:val = s:kv[1]
        if s:val == 'true'
          let s:opts.inputs[s:key] = v:true
        elseif s:val == 'false'
          let s:opts.inputs[s:key] = v:false
        else
          let s:opts.inputs[s:key] = str2float(s:val)
        endif
      endif
    endfor
    let s:i += 2
  elseif s:arg == '--inputs-file' && s:i + 1 < len(s:args)
    let s:opts.inputs_file = s:args[s:i + 1]
    let s:i += 2
  elseif s:arg == '--outputs-file' && s:i + 1 < len(s:args)
    let s:opts.outputs_file = s:args[s:i + 1]
    let s:i += 2
  elseif s:arg == '--result-file' && s:i + 1 < len(s:args)
    let s:opts.result_file = s:args[s:i + 1]
    let s:i += 2
  elseif s:arg == '--props' && s:i + 1 < len(s:args)
    let s:opts.properties = {}
    for s:pair in split(s:args[s:i + 1], ',')
      let s:kv = split(s:pair, '=')
      if len(s:kv) == 2
        let s:key = s:kv[0]
        let s:val = s:kv[1]
        if s:val == 'true'
          let s:opts.properties[s:key] = v:true
        elseif s:val == 'false'
          let s:opts.properties[s:key] = v:false
        else
          let s:num = str2float(s:val)
          let s:opts.properties[s:key] = s:num
        endif
      endif
    endfor
    let s:i += 2
  elseif s:arg == '--help' || s:arg == '-h'
    echo 'Usage: nvim -S bin/stormworks-export.vim -- [options]'
    echo ''
    echo 'Required:'
    echo '  --script <path>              Path to microcontroller script'
    echo '  --output <path>              Output image path'
    echo ''
    echo 'Optional:'
    echo '  --ticks <N>                  Number of ticks to run (default: 1)'
    echo '  --capture <which>            "debug", "game", or "both" (default: "debug")'
    echo '  --format <fmt>               "png" or "jpg" (auto-detected)'
    echo '  --inputs <spec>              Inline inputs: "B1=true,N1=0.5,N2=123"'
    echo '  --inputs-file <path>         JSON file with inputs'
    echo '  --outputs-file <path>        Write outputs to JSON file'
    echo '  --result-file <path>         Write result to JSON file'
    echo '  --tiles <WxH>                Screen tiles (e.g., "3x2")'
    echo '  --debug-canvas-size <WxH>    Debug canvas size (e.g., "512x512")'
    echo '  --props <spec>               Properties: "key=val,key2=val2"'
    echo ''
    echo 'Example:'
    echo '  nvim -S bin/stormworks-export.vim -- \'
    echo '    --script test.lua \'
    echo '    --output output.png \'
    echo '    --ticks 10 \'
    echo '    --inputs "B1=true,N1=0.5"'
    cquit
  else
    let s:i += 1
  endif
endwhile

" Validate required arguments
if s:opts.script is v:null
  echoerr 'Error: Missing required --script argument'
  cquit 1
endif

if s:opts.output is v:null
  echoerr 'Error: Missing required --output argument'
  cquit 1
endif

" Run export
try
  let s:result = luaeval('require("stormworks").export_debug_image_sync(_A)', s:opts)
  
  " Output result as JSON
  echo json_encode(s:result)
  
  " Exit with appropriate code
  if get(s:result, 'success', 0)
    qall!
  else
    cquit! 1
  endif
catch
  echoerr 'Error: ' . v:exception
  cquit 1
endtry
