var updateInterval = 30;
$("#updateInterval").val(updateInterval).change(function() {
    var v = $(this).val();
    if (v && !isNaN(+v)) {
        updateInterval = +v;
        if (updateInterval < 1)
            updateInterval = 1;
        if (updateInterval > 2000)
            updateInterval = 2000;
        $(this).val("" + updateInterval);
    }
});

var data = [],
    totalPoints = 600;

function getRandomData() {
    if (data.length > 0)
        data = data.slice(1);

    while (data.length < totalPoints) {
        var prev = data.length > 0 ? data[data.length - 1] : 50;
        var y = prev + Math.random() * 10 - 5;
        if (y < 0)
            y = 0;
        if (y > 100)
            y = 100;
        data.push(y);
    }

    var res = [];
    for (var i = 0; i < data.length; ++i)
        res.push([i, data[i]]);

    return res;
}

$(function () {
    var options = {
        legend: {
            show: false
        },
        series: {
            shadowSize: 2,
            color: "#ff0000"
        },
        yaxis: {
            min: 0,
            max: 100
        },
        xaxis: {
            show: true
        },
        grid: {
            color: "#0000ff"
        },
        lines: {
            lineWidth: 2,
            fill: true
        }
    };
    var plot = $.plot($("#realtimechart"), [getRandomData()], options);

    function update() {
        plot.setData([getRandomData()]);
        plot.draw();
        setTimeout(update, updateInterval);
    }
    update();
});