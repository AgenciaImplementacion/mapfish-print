/*
 * Copyright (C) 2014  Camptocamp
 *
 * This file is part of MapFish Print
 *
 * MapFish Print is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MapFish Print is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MapFish Print.  If not, see <http://www.gnu.org/licenses/>.
 */

package org.mapfish.print.attribute.map;

import org.json.JSONArray;
import org.mapfish.print.config.Template;
import org.mapfish.print.parser.HasDefaultValue;
import org.mapfish.print.wrapper.PArray;
import org.mapfish.print.wrapper.json.PJsonArray;

import java.awt.Dimension;
/**
 * The attributes for an overview map.
 */
public final class OverviewMapAttribute extends GenericMapAttribute<OverviewMapAttribute.OverviewMapAttributeValues> {
    
    private static final double DEFAULT_ZOOM_FACTOR = 5.0;

    private double zoomFactor = DEFAULT_ZOOM_FACTOR;

    private String style = null;

    /**
     * The zoom factor by which the extent of the main map will be augmented to
     * create an overview.
     * @param zoomFactor The zoom-factor.
     */
    public void setZoomFactor(final double zoomFactor) {
        this.zoomFactor = zoomFactor;
    }

    /**
     * The style name of a style to apply to the bbox rectangle of the original map during rendering.
     * The style name must map to a style in the template or the configuration objects.
     * @param style The style.
     */
    public void setStyle(final String style) {
        this.style = style;
    }

    @SuppressWarnings("unchecked")
    @Override
    protected Class<OverviewMapAttributeValues> getValueType() {
        return OverviewMapAttributeValues.class;
    }

    @Override
    public OverviewMapAttributeValues createValue(final Template template) {
        return new OverviewMapAttributeValues(template, new Dimension(this.getWidth(), this.getHeight()));
    }
    
    /**
     * The value of {@link MapAttribute}.
     */
    public final class OverviewMapAttributeValues extends GenericMapAttribute<?>.GenericMapAttributeValues {
        
        /**
         * The json with all the layer information.  This will be parsed in postConstruct into a list of layers and
         * therefore this field should not normally be accessed.
         */
        @HasDefaultValue
        public PArray layers = new PJsonArray(null, new JSONArray(), null);

        /**
         * The output dpi of the printed map.
         */
        @HasDefaultValue
        public Double dpi = null;
        
        /**
         * Constructor.
         *
         * @param template the template this map is part of.
         * @param mapSize  the size of the map.
         */
        public OverviewMapAttributeValues(final Template template, final Dimension mapSize) {
            super(template, mapSize);
        }

        @Override
        public Double getDpi() {
            return this.dpi;
        }

        @Override
        public PArray getRawLayers() {
            return this.layers;
        }

        public double getZoomFactor() {
            return OverviewMapAttribute.this.zoomFactor;
        }

        public String getStyle() {
            return OverviewMapAttribute.this.style;
        }
    }
}
