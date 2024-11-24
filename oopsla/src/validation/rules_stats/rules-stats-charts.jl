deps = ["DataFrames", "Query", "Gadfly", "Colors", "Compose"]
for d in deps
	if Pkg.installed(d) == nothing
		Pkg.add(d)
	end
end

using DataFrames, Query, Gadfly, Colors, Compose

input_file="rules-stats.csv"
font = "Linux Biolinum"
bar_color = "grey"

lj_stats_chart_theme =
            Theme(
            default_color = parse(Colorant, bar_color), 
            background_color = parse(Colorant, "white"), 
            bar_spacing=1.2mm,
            minor_label_font=font,
            major_label_font=font,
#            minor_label_font_size=9pt,
            major_label_color=parse(Colorant, "black"),
            minor_label_color=parse(Colorant, "black"),
            key_position = :none)


function draw_p1(df)
    # First plot: only count number of times rule fired 
    df1 = DataFrame(Rule_Name = df[:Rule_Name], Fired = df[:Fired])
    
    # +1 to anyone! To make log-scale happy (no 0 after this)
    df11 = @from i in df1 begin
                @select {i.Rule_Name, Fired=i.Fired + 1}
                @collect DataFrame
           end

    # Transpose to fed the table into the renderer
    df1_tr = stack(df11, [:Fired])

    # Last step: plotting
    p1 = Gadfly.plot(df1_tr, 
        x="value", y="Rule_Name", 
        Geom.bar(orientation= :horizontal), 
        Scale.x_log10,
        Guide.xlabel(nothing),
        Guide.ylabel(nothing),
        Guide.xticks(ticks=[0, 1:8;]),
        lj_stats_chart_theme
    )

    draw(PDF("fig-rule-stat-a.pdf",15cm,10cm),p1)
end

function draw_p2(df)
    # Replace total fired counter with failed counter
    df2 = DataFrame(Rule_Name = df[:Rule_Name], Suc_Ratio = (df[:Succeeded] ./ df[:Fired]), Succeeded = df[:Succeeded])

    df2_tr = stack(df2, [:Suc_Ratio])
    
    p2 = Gadfly.plot(df2_tr, 
        x="value", y="Rule_Name",
        Geom.bar(orientation= :horizontal), 
        Guide.xlabel(nothing),
        Guide.ylabel(nothing),
        Guide.xticks(ticks=vcat([0, 0.25, 0.5, 0.75, 1])),
        lj_stats_chart_theme
    )

    draw(PDF("fig-rule-stat-b.pdf",8cm,10cm),p2)
end

function main()
    # Load data from CSV
    df = readtable(input_file)

    # Sort the table to have most common rules at the bottom
    sort!(df, cols = [:Fired], rev=true)

    draw_p1(df)
    draw_p2(df)
end

main()
