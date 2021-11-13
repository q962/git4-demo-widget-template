add_rules("mode.debug", "mode.release")

target("gtk4_demo1")
    set_kind("binary")
    set_pcheader("src/stdafx.h")
    set_runenv("PATH","$(GTK4_BIN_PATH)", os.getenv("PATH"));

    add_files("src/**.c")
    add_defines("UNICODE", "_UNICODE")

    on_load(function(target)
        import("net.http")
        import("core.project.config")
        config.load(".config")

        if not os.isfile("./.xmake/xmakefuns.lua") then
            http.download("https://cdn.jsdelivr.net/gh/q962/xmake_funs/xmake.funs.lua", ".xmake/xmakefuns.lua");
            if not os.isfile("./.xmake/xmakefuns.lua") then
                print("download fail");
                os.exit();
            end
        end

        import("xmakefuns", {alias = "lx", rootdir= ".xmake"});

        if not os.isdir(path.join(target:targetdir(), "res")) then
            local res_dir = path.join(path.relative(".", target:targetdir()), "res");
            os.cd(target:targetdir());
            os.ln(res_dir, "res");
            os.cd(os.projectdir());
        end

        os.addenv("PKG_CONFIG_PATH", config.get("GTK4_DEBUG_PKG_CONFIG_PATH"))

        lx.need(target,
            {"pkgconfig::gtk4 >= 4.4.0"},
            {"*glib-compile-resources", "sassc", "stat"}
        );

        -- 无法判断文件是否被修改，如有必要，写成函数遍历资源文件和输出文件对比日期
        os.run("glib-compile-resources --generate-header --sourcedir res res/res.xml --target src/res.h")
        os.run("glib-compile-resources --generate-source --sourcedir res res/res.xml --target src/res.c")

        if is_host("windows") then
            target:add("defines", "RESDIR=\"res/\"");
            target:add("links", "Gdi32") -- 加载字体函数
        else
            target:add("defines", "RESDIR=\"/usr/share/\"");
        end

        target:add("cflags", "-g3", "-gdwarf-2");
    end)

    before_run(function()
        import("xmakefuns", {alias = "lx", rootdir= ".xmake"});
        import("core.project.config")
        config.load()

        local is_ok = true;

        for _, file_path in ipairs(os.files("$(projectdir)/res/css/*.scss")) do
            local out_path = file_path:gsub("scss$","css");

            if config.get("has_sassc") then
                if not os.isfile(out_path) or lx.do_stat(out_path, file_path) then
                    os.run("sassc " .. file_path .. " " .. out_path)
                else
                    cprint("${red}需要编译 " .. path.relative(file_path) .. " >> " .. path.relative(out_path))
                    is_ok = false;
                end
            end
        end

        if not is_ok then
            os.exit();
        end
    end)
