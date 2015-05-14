if ($("#realtimechart").length) {
    var options = {
        series: {
            shadowSize: 1
        },
        yaxis: {
            min: 0,
            max: 100
        },
        xaxis: {
            show: false
        }
    };
    var plot = $.plot($("#realtimechart"), [getRandomData()], options);

    function update() {
        plot.setData([getRandomData()]);
        plot.draw();
        setTimeout(update, updateInterval);
    }
    update();
}